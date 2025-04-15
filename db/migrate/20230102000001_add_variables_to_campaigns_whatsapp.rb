# db/migrate/20230102000001_add_variables_to_campaigns_whatsapp.rb
class AddVariablesToCampaignsWhatsapp < ActiveRecord::Migration[7.0]
    def change
      add_column :campaigns_whatsapp, :body_variables, :jsonb, default: []
      add_column :campaigns_whatsapp, :button_variables, :jsonb, default: []
    end
  end  