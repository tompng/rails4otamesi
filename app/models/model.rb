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
        childs.keys.each{|child|
          multiple = child =~ /_many$/
          with_parent = child =~ /with_parent/
          if multiple
            has_many child.to_s.pluralize.to_sym
          else
            has_one child
          end
          belongs_to parent.to_sym if parent

          if multiple
            child_name = child.to_s.pluralize.to_sym
            as_name = "as_#{name}".pluralize.to_sym
            sync_childs child_name, include: true
            sync_childs as_name, ->{send child_name}, include: true, with_parent: with_parent
          else
            sync_child child, include: true
            sync_child "as_#{child}".to_sym, ->{send child}, include: true, with_parent: with_parent
          end
        }
        if parent
          sync_parent parent
          multiple = name =~ /_many$/
          as_name = "as_#{name}"
          as_name = as_name.pluralize if name =~ /many/
          sync_parent parent, as: as_name
        end

      }
      Model.const_set name.to_s.camelize, klass
    end
  }
  gen[structure]
end