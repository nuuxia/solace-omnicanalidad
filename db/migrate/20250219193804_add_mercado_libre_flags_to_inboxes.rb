class AddMercadoLibreFlagsToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :mercado_libre_pre_sale_questions, :boolean, default: true, null: false
    add_column :inboxes, :mercado_libre_post_sale_messages, :boolean, default: true, null: false
  end
end
