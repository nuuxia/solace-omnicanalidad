MERCADO_LIBRE = {
  api_key: ENV['MERCADO_LIBRE_APP_ID'],
  secret_key: ENV['MERCADO_LIBRE_SECRET_KEY'],
  auth_url: Rails.application.config.mercado_libre_auth_url,
  redirect_uri: Rails.application.config.mercado_libre_redirect_uri,
  base_url: Rails.application.config.mercado_libre_base_url
}.freeze
