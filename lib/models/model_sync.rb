module ModelSync
  extend ActiveSupport::Concern

  included do
    after_commit :notify_create, on: :create
    after_commit :notify_update, on: :update
    after_commit :notify_destroy, on: :destroy
    class << self
      def sync_parent method, option={}
        unknown_options = option.keys - [:as, :only_to]
        raise "Unknown option #{unknown_options}" if unknown_options.present?
        sync_parents_array << [method, option]
      end

      def sync_parents_array
        @sync_parents ||= []
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

  def notify_to_parent data, recursive_keys=nil, specific = nil
    self.class.sync_parents_array.each{|method, option|
      parent = send method
      next unless parent
      association_info = parent.sync_child_info_for option[:as] || self.class

      if association_info[:multiple]
        key = [association_info[:name], id, *recursive_keys]
      else
        key = [association_info[:name], *recursive_keys]
      end
      if option[:only_to]
        parent_specific = instance_exec &option[:only_to]
        next if parent_specific.nil?
        next if specific && specific != parent_specific
        specific ||= parent_specific
      end
      NodeNotification.notify key: parent, specific: specific, data: data.merge(key: key)
      parent.notify_to_parent data, key, specific if association_info[:include]
    }
  end

  def notify_create
    notify_to_parent type: :created, data: to_notification_hash_with_inclusions
  rescue => e
    Rails.logger.error e
  end

  def notify_update
    notify_to_parent type: :updated, data: to_notification_hash_with_inclusions
    notify_self unless self.class.notify_only_to_parent?
  rescue => e
    Rails.logger.error e
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
      notify_child_update method if option[:with_parent]
    }
  end

  def notify_destroy
    notify_to_parent type: :deleted
    NodeNotification.notify key: self, data: {type: :deleted}
  rescue => e
    Rails.logger.error e
  end

  def to_notification_hash
    as_json
  end

  def to_notification_hash_with_inclusions specific=nil
    data = to_notification_hash
    self.class.sync_childs_hash.each{|name, option|
      next unless option[:include]
      next if option[:block] && option[:block].arity == 1 && specific.nil?
      data[name] = notification_hash_for name, specific
    }
    data
  end

  def sync_child_info_for arg
    if Class === arg
      name = arg.class_name.underscore
      self.class.sync_childs_hash[name] || self.class.sync_childs_hash[name.pluralize]
    else
      self.class.sync_childs_hash[arg]
    end

  end

  def notification_hash_for name, specific=nil
    option = self.class.sync_childs_hash[name]
    block = option[:block]
    if block
      if block.arity == 1
        return if specific.nil?
        child = instance_exec specific, &block
      else
        child = instance_exec &block
      end
    else
      child = send name
    end
    if option[:multiple]
      child.map{|model|[model.id, model.to_notification_hash_with_inclusions(specific)]}.to_h
    else
      ActiveRecord::Base === child ? child.to_notification_hash_with_inclusions(specific) : child
    end
  end

  def to_front_hash specific=nil
    self.class.sync_childs_hash.keys.map{|name|
      [name, notification_hash_for(name, specific)]
    }.to_h.merge to_notification_hash
  end
end
