class RemoveNamesFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :firstname, :string, null: false, default: ""
    remove_column :users, :lastname, :string, null: false, default: ""
  end
end
