module TikTok
  class TokenService
    include HTTParty
    base_uri TIK_TOK[:base_url]

    def initialize(code, code_verifier)
      @code = code
      @code_verifier = code_verifier
      @client_key = TIK_TOK[:api_key]
      @client_secret = TIK_TOK[:secret_key]
      @redirect_uri = TIK_TOK[:redirect_uri]
    end

    def call
      response = self.class.post('/oauth/token/', headers: headers, body: request_body)
      handle_response(response)
    end

    private

    def headers
      {
        'content-type' => 'application/x-www-form-urlencoded'
      }
    end

    def request_body
      {
        grant_type: 'authorization_code',
        client_key: @client_key,
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
        raise StandardError, "Failed to fetch TikTok token: #{response.body}"
      end
    end
  end
end
