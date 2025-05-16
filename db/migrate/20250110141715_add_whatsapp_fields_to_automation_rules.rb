class AddWhatsappFieldsToAutomationRules < ActiveRecord::Migration[7.0]
  def change
    add_column :automation_rules, :inbox_id, :bigint
    add_column :automation_rules, :template_id, :bigint
    add_column :automation_rules, :phone_number, :string

    add_index :automation_rules, :inbox_id
    add_index :automation_rules, :template_id
  end
end
