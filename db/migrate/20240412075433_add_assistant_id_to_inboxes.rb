class AddAssistantIdToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :assistantid, :string
  end
end
