class CreateTopics < ActiveRecord::Migration
  def change
    create_table :topics do |t|
      t.string :title
      t.text :content
      t.references :user

      t.timestamps
    end
    add_index :topics, :user_id
  end
end
