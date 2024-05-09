class CreateConversationThreadRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_thread_records do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :thread_id
      t.string :assistant_id

      t.timestamps
    end
  end
end
