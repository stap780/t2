class DropProjects < ActiveRecord::Migration[8.0]
  def up
    drop_table :projects
  end

  def down
    create_table :projects do |t|
      t.string :title
      t.timestamps
    end
  end
end
