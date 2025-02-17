class AddOfflineResponseToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :offline_response, :boolean, default: false, null: false
  end
end
