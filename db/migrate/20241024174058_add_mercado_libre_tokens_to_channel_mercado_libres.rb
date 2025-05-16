class AddMercadoLibreTokensToChannelMercadoLibres < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_mercado_libres, :mercado_libre_access_token, :string
    add_column :channel_mercado_libres, :mercado_libre_refresh_token, :string
    add_column :channel_mercado_libres, :mercado_libre_token_expires_at, :datetime
    add_column :channel_mercado_libres, :mercado_libre_user_id, :integer
  end
end
