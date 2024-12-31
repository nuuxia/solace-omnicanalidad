module TikTokConcern
  extend ActiveSupport::Concern

  private

  # GENERATE CSRF STATE
  def generate_csrf_state
    SecureRandom.hex(16)
  end

  # TikTokConcern
  def build_tiktok_auth_url(state)
    base_url = TIK_TOK[:auth_url]
    redirect_uri = TIK_TOK[:redirect_uri]
    client_key = TIK_TOK[:api_key]
    scope = 'user.info.basic'

    # Generar el code_verifier y el code_challenge
    code_verifier = generate_code_verifier
    code_challenge = generate_code_challenge(code_verifier)

    # Guardar el code_verifier en la cookie
    cookies[:code_verifier] = { value: code_verifier, expires: 10.minutes.from_now, httponly: true }

    query_params = {
      client_key: client_key,
      response_type: 'code',
      scope: scope,
      redirect_uri: redirect_uri,
      state: state,
      code_challenge: code_challenge,
      code_challenge_method: 'S256'
    }

    "#{base_url}?#{query_params.to_query}"
  end

  # Generar un code_verifier aleatorio
  def generate_code_verifier
    SecureRandom.urlsafe_base64(64)
  end

  # Generar un code_challenge a partir del code_verifier
  def generate_code_challenge(verifier)
    digest = OpenSSL::Digest::SHA256.digest(verifier)
    Base64.urlsafe_encode64(digest).tr('=', '')
  end
end

