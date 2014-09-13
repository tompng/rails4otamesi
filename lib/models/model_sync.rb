module ModelSync
  extend ActiveSupport::Concern

  included do
    after_commit :notify_create, on: :create
    after_commit :notify_update, on: :update
    after_commit :notify_destroy, on: :destroy
    class << self
      def sync_parent method, option={}
        unknown_options = option.keys - [:as]
        raise "Unknown option #{unknown_options}" if unknown_options.present?
        sync_parents_hash[method] = option
      end

      def sync_parents_hash
        @sync_parents ||= ActiveSupport::HashWithIndifferentAccess.new
      end

      def sync_childs_hash
        @sync_childs ||= ActiveSupport::HashWithIndifferentAccess.new
      end

      def sync_childs method, *args
        sync_child_with_multiple true, method, *args
      end

      def sync_child method, *args
        sync_child_with_multiple false, method, *args
      end

      def sync_child_with_multiple multiple, method, *args
        block = args.find{|b|Proc === b}
        option = args.find{|o|Hash === o} || {}
        unknown_options = option.keys - [:with_parent, :include]
        raise "Unknown option #{unknown_options}" if unknown_options.present?
        sync_childs_hash[method] = option.merge name: method, multiple: multiple, block: block
      end

      def notify_only_to_parent?
        @sync_only_to_parent
      end

      def notify_only_to_parent
        @sync_only_to_parent = true
      end
    end
  end

  def notify_to_parent data, recursive_keys=nil
    self.class.sync_parents_hash.each{|method, option|
      parent = send method
      next unless parent
      association_info = parent.sync_child_info_for option[:as] || self.class

      if association_info[:multiple]
        key = [association_info[:name], id, *recursive_keys]
      else
        key = [association_info[:name], *recursive_keys]
      end

      NodeNotification.notify key: parent, data: data.merge(key: key)
      parent.notify_to_parent data, key if association_info[:include]
    }
  end

  def notify_create
    notify_to_parent type: :created, data: to_notification_hash_with_inclusions
  end

  def notify_update
    notify_to_parent type: :updated, data: to_notification_hash_with_inclusions
    notify_self unless self.class.notify_only_to_parent?
  end

  def notify_child_update name
    NodeNotification.notify key: self, data: {
      type: :updated,
      key: [name],
      data: notification_hash_for(name)
    }
  end

  def notify_self
    NodeNotification.notify key: self, data: {
      type: :updated,
      data: to_notification_hash
    }
    self.class.sync_childs_hash.each{|method, option|
      next unless option[:with_parent]
      notify_child_update method
    }
  end

  def notify_destroy
    notify_to_parent type: :deleted
    NodeNotification.notify key: self, data: {type: :deleted}
  end

  def to_notification_hash
    as_json
  end

  def to_notification_hash_with_inclusions
    data = to_notification_hash
    self.class.sync_childs_hash.select{|name, option|
      data[name] = notification_hash_for name if option[:include]
    }
    data
  end

  def sync_child_info_for arg
    if Class === arg
      name = arg.name.underscore
      self.class.sync_childs_hash[name] || self.class.sync_childs_hash[name.pluralize]
    else
      self.class.sync_childs_hash[arg]
    end

  end

  def notification_hash_for name
    option = self.class.sync_childs_hash[name]
    if option[:block]
      child = instance_exec &option[:block]
    else
      child = send name
    end
    if option[:multiple]
      child.map{|model|[model.id, model.to_notification_hash_with_inclusions]}.to_h
    else
      ActiveRecord::Base === child ? child.to_notification_hash_with_inclusions : child
    end
  end

  def to_front_hash
    self.class.sync_childs_hash.keys.map{|name|
      [name, notification_hash_for(name)]
    }.to_h.merge to_notification_hash_with_inclusions
  end
end
