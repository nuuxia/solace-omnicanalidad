# app/services/whatsapp/providers/automated_whatsapp_cloud_service.rb
module Whatsapp
  module Providers
    class AutomatedWhatsappCloudService
      def initialize(account_id:, waba_id:, phone_number_id:, business_id: nil)
        @account_id       = account_id
        @waba_id          = waba_id
        @phone_number_id  = phone_number_id
        @business_id      = business_id
        @version          = ENV.fetch('FB_GRAPH_API_VERSION', nil)
        @access_token     = ENV.fetch('SYSTEM_USER_ACCESS_TOKEN', nil)
        @pin              = ENV.fetch('FB_CONFIG_PIN', nil)
      end

      def call
        return nil unless valid_environment_variables?

        if register_phone_number && subscribe_app_to_waba
          details = fetch_and_log_phone_number_details
          inbox   = create_inbox(details) if details
          return {
            inbox_id: inbox&.id,
            waba_id: @waba_id,
            phone_number_id: @phone_number_id
          }
        end

        nil
      end

      private

      def valid_environment_variables?
        @version.present? && @access_token.present? && @pin.present?
      end

      def register_phone_number
        url = "https://graph.facebook.com/#{@version}/#{@phone_number_id}/register"

        response = Faraday.post(url) do |req|
          req.headers['Authorization'] = "Bearer #{@access_token}"
          req.headers['Content-Type']  = 'application/json'
          req.body = {
            messaging_product: 'whatsapp',
            pin: @pin
          }.to_json
        end

        handle_response(response, 'Registro del número de teléfono')
      end

      def subscribe_app_to_waba
        url = "https://graph.facebook.com/#{@version}/#{@waba_id}/subscribed_apps"

        response = Faraday.post(url) do |req|
          req.headers['Authorization'] = "Bearer #{@access_token}"
          req.headers['Content-Type']  = 'application/json'
          req.body = {}.to_json
        end

        handle_response(response, 'Suscripción de la aplicación al WABA')
      end

      def fetch_and_log_phone_number_details
        url = "https://graph.facebook.com/#{@version}/#{@waba_id}/phone_numbers"

        response = Faraday.get(url) do |req|
          req.headers['Authorization'] = "Bearer #{@access_token}"
        end

        if response.success?
          process_phone_number_response(response.body)
        else
          Rails.logger.error "⛔️ Error obteniendo detalles del número. Código: #{response.status}, Respuesta: #{response.body}"
          nil
        end
      rescue StandardError => e
        Rails.logger.error "⚠️ Excepción al obtener detalles del número: #{e.message}"
        nil
      end

      def process_phone_number_response(response_body)
        data = JSON.parse(response_body)['data']
        matching = data.find { |phone| phone['id'] == @phone_number_id }

        if matching
          display = clean_phone_number(matching['display_phone_number'])
          name    = matching['verified_name']

          {
            inbox_name: name,
            phone_number: display,
            phone_number_id: @phone_number_id,
            business_account_id: @waba_id,
            api_key: @access_token
          }
        else
          Rails.logger.warn "⚠️ No se encontró phone_number_id #{@phone_number_id} en la respuesta."
          nil
        end
      end

      def clean_phone_number(number)
        "+#{number.gsub(/\D/, '')}"
      end

      def create_inbox(details)
        channel = Channel::Whatsapp.create!(
          account_id: @account_id,
          phone_number: details[:phone_number],
          provider: 'whatsapp_cloud',
          provider_config: {
            api_key: details[:api_key],
            phone_number_id: details[:phone_number_id],
            business_account_id: details[:business_account_id]
          }
        )

        Inbox.create!(
          account_id: @account_id,
          name: details[:inbox_name],
          channel: channel
        )
      rescue StandardError => e
        Rails.logger.error "⛔️ Error creando el inbox: #{e.message}"
        raise
      end

      def handle_response(response, action_name)
        if response.success?
          true
        else
          Rails.logger.error "⛔️ Error en #{action_name}. Código: #{response.status}, Respuesta: #{response.body}"
          false
        end
      rescue StandardError => e
        Rails.logger.error "⚠️ Excepción en #{action_name}: #{e.message}"
        false
      end
    end
  end
end
