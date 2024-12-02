# app/services/mercado_libre/refresh_token_service.rb
module MercadoLibre
  class RefreshTokenService
    include HTTParty
    base_uri 'https://api.mercadolibre.com'
    def initialize(channel)
      @channel = channel
      @client_id = MERCADO_LIBRE[:api_key]
      @client_secret = MERCADO_LIBRE[:secret_key]
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
        grant_type: 'refresh_token',
        client_id: @client_id,
        client_secret: @client_secret,
        refresh_token: @channel.mercado_libre_refresh_token
      }
    end
    def handle_response(response)
      if response.success?
        JSON.parse(response.body)
      else
        raise StandardError, "Failed to refresh Mercado Libre token: #{response.body}"
      end
    end
  end
end
