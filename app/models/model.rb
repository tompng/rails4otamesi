class Model
  def self.structure
    {
      root: {
        branch_one: {
          leaf_one_one: {},
          leaf_one_many: {}
        },
        branch_many: {
          leaf_many_one: {},
          leaf_many_many: {}
        },
        branch_with_parent_one: {},
        branch_with_parent_many: {}
      }
    }
  end
  gen = ->(hash, parent=nil){
    hash.each do |name, childs|
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = name
      gen[childs, name]
      klass.class_eval{
        include ::ModelSync
        define_method :to_notification_hash do
          as_json.merge rand: rand
        end
        childs.keys.each{|child|
          with_parent = child =~ /with_parent/
          if child =~ /_many$/
            child_name = child.to_s.pluralize.to_sym
            as_name = "as_#{child}".pluralize.to_sym
            has_many child_name
            sync_childs child_name, include: true, with_parent: with_parent
            sync_childs as_name, ->{send child_name}, include: true, with_parent: with_parent
          else
            has_one child
            sync_child child, include: true, with_parent: with_parent
            sync_child "as_#{child}".to_sym, ->{send child}, include: true, with_parent: with_parent
          end
        }
        if parent
          belongs_to parent
          sync_parent parent
          as_name = "as_#{name}"
          as_name = as_name.pluralize if name =~ /_many$/
          sync_parent parent, as: as_name
        end

      }
      Model.const_set name.to_s.camelize, klass
    end
  }
  gen[structure]
end