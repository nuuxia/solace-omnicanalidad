module MercadoLibreConcern
  extend ActiveSupport::Concern
  private
  def generate_code_verifier
    SecureRandom.hex(32)
  end
  def generate_code_challenge(code_verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier)).tr('=', '')
  end
  def mercado_libre_auth_url(code_challenge)
    app_id = MERCADO_LIBRE[:api_key]
    redirect_uri = MERCADO_LIBRE[:redirect_uri]
    "#{MERCADO_LIBRE[:auth_url]}?response_type=code&client_id=#{app_id}&redirect_uri=#{redirect_uri}&code_challenge=#{code_challenge}&code_challenge_method=S256"
  end
end
