class CreateModelTables < ActiveRecord::Migration
  def change
    gen(Model.structure)
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


