module MercadoLibre
  class TokenService
    include HTTParty
    base_uri MERCADO_LIBRE[:base_url]

    def initialize(code, code_verifier)
      @code = code
      @code_verifier = code_verifier
      @client_id = MERCADO_LIBRE[:api_key]
      @client_secret = MERCADO_LIBRE[:secret_key]
      @redirect_uri = MERCADO_LIBRE[:redirect_uri]
    end
    def call
      response = self.class.post('/oauth/token', headers: headers, body: request_body)
      handle_response(response)
    end
    private
    def headers
      {
        'accept' => 'application/json',
        'content-type' => 'application/x-www-form-urlencoded'
      }
    end
    def request_body
      {
        grant_type: 'authorization_code',
        client_id: @client_id,
        client_secret: @client_secret,
        code: @code,
        redirect_uri: @redirect_uri,
        code_verifier: @code_verifier
      }
    end
    def handle_response(response)
      if response.success?
        JSON.parse(response.body)
      else
        raise StandardError, "Failed to fetch Mercado Libre token: #{response.body}"
      end
    end
  end
end
