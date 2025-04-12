# app/services/whatsapp/send_flow_service.rb
module Whatsapp
  class SendFlowService
    def initialize(inbox:, to:, flow_button_data:)
      @inbox           = inbox
      @to              = to
      @flow_button_data = flow_button_data
    end

    def perform
      return if @flow_button_data.blank?

      Rails.logger.info "[SendFlowService] Iniciando envío de Flow a #{@to}"

      payload = build_payload
      Rails.logger.info "[SendFlowService] Payload construido: #{payload.to_json}"

      response = send_message(payload)
      process_response(response)
    end

    private

    def build_payload
      {
        messaging_product: 'whatsapp',
        to: @to,
        type: 'interactive',
        interactive: {
          type: 'flow',
          locale: 'en_US', # o el idioma que corresponda, p.ej. 'es'
          flow_id: @flow_button_data[:flow_id],
          flow_action: @flow_button_data[:flow_action],
          # Esto depende de la doc y del action (NAVIGATE, etc.)
          navigate_params: {
            screen_id: @flow_button_data[:navigate_screen]
          }
          # O en su defecto, si tu flow requiere "flow_params" en lugar de "navigate_params":
          # flow_params: {
          #   some_key: "some_value"
          # }
        }
      }
    end

    def send_message(payload)
      url = "https://graph.facebook.com/#{ENV['VITE_FB_GRAPH_API_VERSION']}/#{@inbox.phone_number_id}/messages"
      headers = {
        'Content-Type'  => 'application/json',
        'Authorization' => "Bearer #{@inbox.whatsapp_api_key}"
      }

      Faraday.post(url, payload.to_json, headers)
    rescue Faraday::Error => e
      Rails.logger.error "[SendFlowService] Faraday Error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "[SendFlowService] Error inesperado: #{e.message}"
      nil
    end

    def process_response(response)
      if response.nil?
        Rails.logger.error "[SendFlowService] Respuesta nil. Error de red?"
        return
      end

      if response.success?
        Rails.logger.info "[SendFlowService] Flow enviado correctamente. HTTP #{response.status}"
      else
        Rails.logger.error "[SendFlowService] Error al enviar flow. Status: #{response.status}, Body: #{response.body}"
      end

      response
    end
  end
end
