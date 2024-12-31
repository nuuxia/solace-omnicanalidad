TIK_TOK = {
  api_key: ENV['TIK_TOK_APP_ID'],
  secret_key: ENV['TIK_TOK_SECRET_KEY'],
  auth_url: Rails.application.config.tik_tok_auth_url,
  redirect_uri: Rails.application.config.tik_tok_redirect_uri,
  base_url: Rails.application.config.tik_tok_base_url
}.freeze
