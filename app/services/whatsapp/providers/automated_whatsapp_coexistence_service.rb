# frozen_string_literal: true

module Whatsapp
  module Providers
    class AutomatedWhatsappCoexistenceService
      def initialize(account_id:, waba_id:, phone_number_id: nil, business_id: nil)
        @account_id   = account_id
        @waba_id      = waba_id
        @business_id  = business_id # por si lo querés guardar más adelante
        @version      = ENV.fetch('FB_GRAPH_API_VERSION', nil)
        @access_token = ENV.fetch('SYSTEM_USER_ACCESS_TOKEN', nil)
      end

      def call
        return unless env_ok?

        phone_id, display_number, verified_name = fetch_first_phone_number
        return unless phone_id
        return unless subscribe_app_to_waba

        inbox = create_inbox(
          inbox_name: verified_name,
          phone_number: clean_phone_number(display_number),
          phone_number_id: phone_id
        )

        {
          inbox_id: inbox&.id,
          waba_id: @waba_id,
          phone_number_id: phone_id
        }
      end

      private

      # ------------------------------------------------------------------
      # helpers
      # ------------------------------------------------------------------
      def env_ok?
        @version.present? && @access_token.present?
      end

      # GET /{WABA-ID}/phone_numbers
      def fetch_first_phone_number
        url = "https://graph.facebook.com/#{@version}/#{@waba_id}/phone_numbers"
        res = Faraday.get(url) { |r| r.headers['Authorization'] = "Bearer #{@access_token}" }

        return unless res.success?

        data   = JSON.parse(res.body)['data']
        first  = data.first
        return unless first

        [first['id'], first['display_phone_number'], first['verified_name']]
      rescue StandardError => e
        Rails.logger.error "⛔️ Error al obtener phone_numbers: #{e.message}"
        nil
      end

      # POST /{WABA-ID}/subscribed_apps
      def subscribe_app_to_waba
        url = "https://graph.facebook.com/#{@version}/#{@waba_id}/subscribed_apps"
        res = Faraday.post(url) do |r|
          r.headers['Authorization'] = "Bearer #{@access_token}"
          r.headers['Content-Type']  = 'application/json'
          r.body = {}.to_json
        end
        res.success?
      rescue StandardError => e
        Rails.logger.error "⛔️ Error al suscribir la app al WABA: #{e.message}"
        false
      end

      def clean_phone_number(number)
        "+#{number.gsub(/\D/, '')}"
      end

      def create_inbox(inbox_name:, phone_number:, phone_number_id:)
        channel = Channel::Whatsapp.create!(
          account_id: @account_id,
          phone_number: phone_number,
          provider: 'whatsapp_cloud',
          provider_config: {
            api_key: @access_token,   # se toma del .env
            phone_number_id: phone_number_id,
            business_account_id: @waba_id
          }
        )

        Inbox.create!(
          account_id: @account_id,
          name: inbox_name,
          channel: channel
        )
      rescue StandardError => e
        Rails.logger.error "⛔️ Error al crear el inbox: #{e.message}"
        nil
      end
    end
  end
end
