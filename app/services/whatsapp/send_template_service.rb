# frozen_string_literal: true

module Whatsapp
  class SendTemplateService
    attr_reader :phone_number_id, :version, :to, :template, :token

    def initialize(phone_number_id:, version:, to:, template:, token:)
      @phone_number_id = phone_number_id
      @version         = version
      @to              = to
      @template        = template
      @token           = token
    end

    def perform
      return nil if template.blank? || template['name'].blank?

      Rails.logger.info "[SendTemplateService] Iniciando envío de template '#{template['name']}' a #{to}"

      payload = build_payload
      Rails.logger.info "[SendTemplateService] Payload construido: #{payload.to_json}"

      faraday_response = send_message(payload)

      if faraday_response.nil? || !faraday_response.is_a?(Faraday::Response)
        Rails.logger.error "[SendTemplateService] Faraday devolvió nil o un objeto inválido (#{faraday_response.inspect})."
        return nil
      end

      if faraday_response.success?
        Rails.logger.info "[SendTemplateService] Mensaje enviado correctamente. HTTP #{faraday_response.status}"
      else
        Rails.logger.error "[SendTemplateService] Error al enviar mensaje. Status: #{faraday_response.status}, Body: #{faraday_response.body}"
      end

      parse_json_body(faraday_response.body)
    end

    private

    def build_payload
      lang_code = if template['language'].is_a?(Hash)
                    template.dig('language', 'code')
                  elsif template['language'].is_a?(String)
                    template['language']
                  end
      lang_code ||= 'en'

      {
        messaging_product: 'whatsapp',
        to:                to,
        type:              'template',
        template: {
          name:       template['name'],
          language:   { code: lang_code },
          components: build_components
        }
      }
    end

    def build_components
      final_components = []
      template_components = template['components'] || []

      # BODY
      body_component = template_components.find { |c| c['type'] == 'BODY' }
      body_params    = template['_cloudapi_body_params'] || []
      if body_component && body_params.any?
        final_components << {
          type: 'BODY',
          parameters: body_params.map { |value| { type: 'text', text: value.to_s } }
        }
      end

      # HEADER
      header_component = template_components.find { |c| c['type'] == 'HEADER' }
      if header_component
        format  = header_component['format']
        example = header_component.dig('example', 'header_handle') || []
        if %w[DOCUMENT IMAGE VIDEO].include?(format) && example.any?
          media_url = example.first
          case format
          when 'DOCUMENT'
            filename_example = header_component.dig('example', 'header_filename') || []
            doc_filename     = filename_example.first || 'file'
            final_components << {
              type: 'HEADER',
              parameters: [
                {
                  type: 'document',
                  document: {
                    link:     media_url,
                    filename: doc_filename
                  }
                }
              ]
            }
          when 'IMAGE'
            final_components << {
              type: 'HEADER',
              parameters: [
                {
                  type: 'image',
                  image: { link: media_url }
                }
              ]
            }
          when 'VIDEO'
            final_components << {
              type: 'HEADER',
              parameters: [
                {
                  type: 'video',
                  video: { link: media_url }
                }
              ]
            }
          end
        end
      end

      # BUTTONS
      buttons_component = template_components.find { |c| c['type'] == 'BUTTONS' }
      if buttons_component && buttons_component['buttons'].present?
        dynamic_buttons = []
        buttons_component['buttons'].each_with_index do |btn, idx|
          # Permitirlo si:
          #   - es dynamic==true  O
          #   - es un tipo FLOW (puedes ajustarlo a tu gusto)
          is_flow = (btn['type'] == 'FLOW')
          next unless btn['dynamic'] == true || is_flow

          sub_type = determine_sub_type(btn)
          next unless sub_type

          parameters = build_button_parameters(sub_type, btn)
          next if parameters.blank?

          dynamic_buttons << {
            type: 'BUTTON',
            sub_type: sub_type,
            index: idx.to_s,
            parameters: parameters
          }
        end
        final_components.concat(dynamic_buttons) if dynamic_buttons.any?
      end

      final_components
    end

    def determine_sub_type(btn)
      case btn['type']
      when 'URL'
        'url'
      when 'PHONE_NUMBER'
        'phone_number'
      when 'COPY_CODE'
        'copy_code'
      when 'FLOW'
        # NUEVO: un botón de tipo flow
        'flow'
      else
        nil
      end
    end

    def build_button_parameters(sub_type, btn)
      case sub_type
      when 'url'
        url = btn['url']
        return [] if url.blank?
        example = btn['example'] || [url]
        [{ type: 'text', text: example.first }]
      when 'phone_number'
        phone_value = btn['phone_number'].to_s
        return [] if phone_value.strip.empty?
        [{ type: 'text', text: phone_value }]
      when 'copy_code'
        code_value = btn.dig('example', 0).to_s
        return [] if code_value.strip.empty?
        [{ type: 'coupon_code', coupon_code: code_value }]
      when 'flow'
        # Ajusta estos campos según lo que envíes en tu template
        flow_id = btn['flow_id']   # p. ej. 697914342899830
        # Típicamente el "flow_token" es el flow_id
        flow_action_data = btn['flow_action_data'] || {}
        # O si guardaste "navigate_screen", "flow_action", etc., inclúyelos aquí
        [{
          type: 'action',
          action: {
            flow_token: flow_id.to_s,
            flow_action_data: flow_action_data
          }
        }]
      else
        []
      end
    end

    def send_message(payload)
      url = "https://graph.facebook.com/#{version}/#{phone_number_id}/messages"
      headers = {
        'Content-Type'  => 'application/json',
        'Authorization' => "Bearer #{token}"
      }

      response = Faraday.post(url, payload.to_json, headers)
      Rails.logger.debug "[SendTemplateService#send_message] Faraday.post => status=#{response.status}, body=#{response.body}"
      response
    rescue Faraday::Error => e
      Rails.logger.error "[SendTemplateService] Faraday Error: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "[SendTemplateService] Error inesperado: #{e.message}"
      nil
    end

    def parse_json_body(body_str)
      return nil if body_str.blank?
      JSON.parse(body_str)
    rescue JSON::ParserError => e
      Rails.logger.error "[SendTemplateService] Error parseando JSON: #{e.message}"
      nil
    end
  end
end