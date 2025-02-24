# app/services/mercado_libre/get_user_info.rb
module MercadoLibre
  class GetUserInfoService
    pattr_initialize [:inbox!]
    def perform
      client = initialize_client
      fetch_user_details(client)
    end

    def initialize_client
      channel = inbox.channel
      channel.ensure_token_valid
      MercadoLibre::Client.new(channel.mercado_libre_access_token)
    end

    private

    def fetch_user_details(client)
      client.fetch_user_details
    rescue StandardError => e
      Rails.logger.error("Error fetching user details: #{e.message}")
      nil
    end
  end
end
