# frozen_string_literal: true

require 'faraday'
require 'json'

module Whatsapp
  class SendTemplateService
    attr_reader :phone_number_id, :version, :to, :template, :token

    def initialize(phone_number_id:, version:, to:, template:, token:)
      @phone_number_id = phone_number_id
      @version = version
      @to = to
      @template = template
      @token = token
    end

    def perform
      return if template.blank? || template['name'].blank?

      Rails.logger.info "[SendTemplateService] Iniciando envío de template '#{template['name']}' a #{to}"

      payload = build_payload
      Rails.logger.info "[SendTemplateService] Payload construido: #{payload.to_json}"

      response = send_message(payload)

      if response.success?
        Rails.logger.info "[SendTemplateService] Mensaje enviado correctamente. Respuesta: #{response.body}"
      else
        Rails.logger.error "[SendTemplateService] Error al enviar mensaje. Status: #{response.status}, Body: #{response.body}"
      end

      response
    end

    private

    # Construye el payload principal.
    # - Ajusta el lenguaje, en caso de que template['language'] sea un String o un Hash.
    # - Añade las "components" en mayúsculas (BODY, HEADER, BUTTON), sin FOOTER.
    def build_payload
      # language: si es un string, lo tomamos tal cual; si es un hash, sacamos el code
      lang_code = if template['language'].is_a?(Hash)
                    template.dig('language', 'code')
                  elsif template['language'].is_a?(String)
                    template['language'] # el string es el código
                  end

      lang_code ||= 'en'  # Valor por defecto si no hay nada

      {
        messaging_product: 'whatsapp',
        to: to,
        type: 'template',
        template: {
          name: template['name'],
          language: {
            code: lang_code
          },
          components: build_components
        }
      }
    end

    # Construye los componentes que la Cloud API sí soporta: BODY, HEADER y BUTTON.
    # - FOOTER se omite en el payload (la Cloud API lo ignora / no lo admite como "type": "FOOTER").
    def build_components
      final_components = []

      # 1. BODY en mayúsculas
      body_component = template_components.find { |c| c['type'] == 'BODY' }
      body_params = template['_cloudapi_body_params'] || []
      if body_component && body_params.any?
        final_components << {
          type: 'BODY',
          parameters: body_params.map do |value|
            {
              type: 'text',
              text: value.to_s
            }
          end
        }
      end

      # 2. HEADER (imágenes, documentos o videos con placeholders)
      header_component = template_components.find { |c| c['type'] == 'HEADER' }
      if header_component
        format = header_component['format']
        example = header_component.dig('example', 'header_handle') || []
        if %w[DOCUMENT IMAGE VIDEO].include?(format) && example.any?
          media_url = example.first
          case format
          when 'DOCUMENT'
            filename_example = header_component.dig('example', 'header_filename') || []
            document_filename = filename_example.first || 'file'
            final_components << {
              type: 'HEADER',
              parameters: [
                {
                  type: 'document',
                  document: {
                    link: media_url,
                    filename: document_filename
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
                  image: {
                    link: media_url
                  }
                }
              ]
            }
          when 'VIDEO'
            final_components << {
              type: 'HEADER',
              parameters: [
                {
                  type: 'video',
                  video: {
                    link: media_url
                  }
                }
              ]
            }
          end
        end
      end

      # 3. FOOTER NO se envía. La Cloud API no lo admite como "type": "FOOTER".
      #    Si tu template tiene un footer estático, WhatsApp lo muestra igual.

      # 4. BUTTONS (sólo los dinámicos), conservando su índice original
      buttons_component = template_components.find { |c| c['type'] == 'BUTTONS' }
      if buttons_component && buttons_component['buttons'].present?
        dynamic_buttons = []

        buttons_component['buttons'].each_with_index do |btn, idx|
          # Si el botón es "dynamic" == true, lo incluimos en el payload
          next unless btn['dynamic'] == true

          sub_type = determine_sub_type(btn) # => "url", "phone_number", "copy_code", etc.
          next unless sub_type

          parameters = build_button_parameters(sub_type, btn)
          next if parameters.blank?

          # Para la Cloud API => type debe ser "BUTTON", en singular
          dynamic_buttons << {
            type: 'BUTTON',
            sub_type: sub_type,
            index: idx.to_s,   # Respetamos el índice tal cual el template
            parameters: parameters
          }
        end

        # Si hay botones dinámicos, los añadimos
        final_components << dynamic_buttons if dynamic_buttons.any?
      end

      final_components.flatten
    end

    # Mapeamos el type interno del botón a sub_type para la Cloud API.
    # - "URL" => "url"
    # - "PHONE_NUMBER" => "phone_number" (o "voice_call", depende de tu template)
    # - "COPY_CODE" => "copy_code"
    def determine_sub_type(btn)
      case btn['type']
      when 'URL'
        'url'
      when 'PHONE_NUMBER'
        'phone_number'
      when 'COPY_CODE'
        'copy_code'
      else
        nil
      end
    end

    # Construye los "parameters" según el sub_type.
    # - "url" => [{ type: "text", text: "<valor>" }]
    # - "phone_number" => [{ type: "text", text: "<phone>" }]
    # - "copy_code" => [{ type: "coupon_code", coupon_code: "xxx" }]
    def build_button_parameters(sub_type, btn)
      case sub_type
      when 'url'
        url_value = btn.dig('example', 0).to_s
        return [] if url_value.strip.empty?

        [
          {
            type: 'text',
            text: url_value
          }
        ]

      when 'phone_number'
        phone_value = btn['phone_number'].to_s
        return [] if phone_value.strip.empty?

        [
          {
            type: 'text',
            text: phone_value
          }
        ]

      when 'copy_code'
        code_value = btn.dig('example', 0).to_s
        return [] if code_value.strip.empty?

        [
          {
            type: 'coupon_code',
            coupon_code: code_value
          }
        ]

      else
        []
      end
    end

    # Envía la request a la API de WhatsApp Cloud
    def send_message(payload)
      url = "https://graph.facebook.com/#{version}/#{phone_number_id}/messages"
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }

      Faraday.post(url, payload.to_json, headers)
    end

    def template_components
      template['components'] || []
    end
  end
end
