# db/migrate/20250624150000_create_campaigns_csv_whatsapp.rb
# frozen_string_literal: true

class CreateCsvCampaignsWhatsapp < ActiveRecord::Migration[7.0]
  def change
    create_table :campaigns_csv_whatsapp do |t|
      # ─────────── Relaciones ───────────
      t.references :account, null: false, foreign_key: true
      t.references :inbox,   null: false, foreign_key: true
      t.references :sender,  foreign_key: { to_table: :users }

      # ─────────── Datos base ───────────
      t.string :title, null: false

      # JSON config del template
      t.jsonb :template,         default: {}
      t.jsonb :body_variables,   default: []
      t.jsonb :button_variables, default: []
      t.jsonb :audience,         default: []

      # Programación / estado
      t.boolean  :enabled, default: true
      t.datetime :scheduled_at
      t.integer  :campaign_status, default: 0 # enum
      t.integer  :messages_total,  default: 0
      t.integer  :messages_sent,   default: 0
      t.integer  :messages_failed, default: 0

      # Archivos CSV en S3 (nombres locales + URLs públicas)
      t.string :original_csv_filename
      t.string :processed_csv_filename

      # ➜ IMPORTANTE: ahora son `text`
      t.text :csv_original_url          # URL pre-firmada del CSV original
      t.text :csv_sent_url              # CSV con envíos exitosos (opcional)
      t.text :csv_errors_url            # CSV con errores (opcional)

      t.timestamps
    end

    # ─────────── Índices ───────────
    add_index :campaigns_csv_whatsapp, :scheduled_at
    add_index :campaigns_csv_whatsapp, :campaign_status
    add_index :campaigns_csv_whatsapp, :template,         using: :gin
    add_index :campaigns_csv_whatsapp, :body_variables,   using: :gin
    add_index :campaigns_csv_whatsapp, :button_variables, using: :gin
  end
end
