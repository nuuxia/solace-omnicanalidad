class CreateCsvCampaignsWhatsapp < ActiveRecord::Migration[7.0]
  def change
    create_table :campaigns_csv_whatsapp do |t|
      t.references :account,  null: false, foreign_key: true
      t.references :inbox,    null: false, foreign_key: true
      t.string  :title,       null: false
      t.jsonb   :template,    default: {}
      t.jsonb   :body_variables,   default: []
      t.jsonb   :button_variables, default: []
      t.jsonb   :audience,    default: []
      t.boolean :enabled,     default: true
      t.datetime :scheduled_at
      t.integer :campaign_status, default: 0
      t.integer :messages_total,   default: 0
      t.integer :messages_sent,    default: 0
      t.integer :messages_failed,  default: 0
      t.timestamps
    end

    add_index :campaigns_csv_whatsapp, :scheduled_at
    add_index :campaigns_csv_whatsapp, :campaign_status
  end
end
