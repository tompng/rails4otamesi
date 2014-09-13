class CreateModelTables < ActiveRecord::Migration
  def change
    gen(
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
    )
  end

  def gen hash, parent=nil
    hash.each do |name, childs|
      create_table name do |t|
        t.references parent if parent
        t.string :name
        t.string :content
        t.string "content_#{name}"
      end
      gen childs, name
    end
  end
end


