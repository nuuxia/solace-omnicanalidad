class CreateCampaignsWhatsapp < ActiveRecord::Migration[7.0]
    def change
      drop_table :campaigns_whatsapp, if_exists: true
      create_table :campaigns_whatsapp do |t|
        t.references :account, null: false, foreign_key: true, index: { name: 'index_campaigns_whatsapp_on_account_id' }
        t.references :inbox, null: false, foreign_key: true, index: { name: 'index_campaigns_whatsapp_on_inbox_id' }
        t.string  :title, null: false
        t.jsonb   :template, default: {}
        t.boolean :enabled, default: true
        t.boolean :trigger_only_during_business_hours, default: false
        t.integer :sender_id
        t.datetime :scheduled_at
        t.jsonb   :audience, default: []
        t.jsonb   :trigger_rules, default: {}
        t.integer :campaign_status, default: 0
        t.integer :campaign_type, default: 0
        t.integer :messages_total, default: 0, null: false
        t.integer :messages_sent, default: 0, null: false
        t.integer :messages_failed, default: 0, null: false
        t.timestamps
      end
      add_index :campaigns_whatsapp, :scheduled_at, name: 'index_campaigns_whatsapp_on_scheduled_at'
      add_index :campaigns_whatsapp, :campaign_status, name: 'index_campaigns_whatsapp_on_campaign_status'
      add_index :campaigns_whatsapp, :campaign_type, name: 'index_campaigns_whatsapp_on_campaign_type'
    end
  end