# frozen_string_literal: true

require 'json'

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

    # ----------------------------------------------------------------
    # Lanza StandardError cuando Meta responde con error (HTTP != 2xx
    # o bien JSON { error: … } )
    # ----------------------------------------------------------------
    def perform
      return nil if template.blank? || template['name'].blank?

      Rails.logger.info "[SendTemplateService] Enviando template '#{template['name']}' → #{to}"
      payload = build_payload
      Rails.logger.debug { "[SendTemplateService] Payload: #{payload.to_json}" }

      response = send_message(payload)

      if response&.success?
        parsed = parse_json_body(response.body)
        api_error = parsed.is_a?(Hash) ? parsed['error'] : nil
        raise StandardError, api_error['message'] if api_error.present?

        return parsed
      end

      status = response&.status || 'nil'
      body   = response&.body   || ''
      meta_msg = begin
        JSON.parse(body).dig('error', 'message')
      rescue JSON::ParserError
        nil
      end
      raise StandardError, (meta_msg.presence || "HTTP #{status}: #{body}")
    end

    # ----------------------------------------------------------------
    private

    # ----------------------------------------------------------------

    def build_payload
      lang_code =
        case template['language']
        when Hash   then template.dig('language', 'code')
        when String then template['language']
        end || 'en'

      {
        messaging_product: 'whatsapp',
        to: to,
        type: 'template',
        template: {
          name: template['name'],
          language: { code: lang_code },
          components: build_components
        }
      }
    end

    # ---------- components helpers ----------------------------------
    def build_components
      comps = []
      template_comps = template['components'] || []

      # BODY ----------------------------------------------------------
      body = template_comps.find { |c| c['type'] == 'BODY' }
      body_params = template['_cloudapi_body_params'] || []
      if body && body_params.any?
        comps << {
          type: 'BODY',
          parameters: body_params.map { |v| { type: 'text', text: v.to_s } }
        }
      end

      # HEADER (IMAGE / VIDEO / DOCUMENT) ----------------------------
      header = template_comps.find { |c| c['type'] == 'HEADER' }
      comps << build_header_component(header) if header

      # BUTTONS -------------------------------------------------------
      buttons = template_comps.find { |c| c['type'] == 'BUTTONS' }
      comps.concat(build_buttons_components(buttons)) if buttons

      comps.compact
    end

    def build_header_component(header_component)
      format  = header_component['format']
      example = header_component.dig('example', 'header_handle') || []
      return if example.empty? || !%w[DOCUMENT IMAGE VIDEO].include?(format)

      media_url = example.first
      case format
      when 'DOCUMENT'
        filename_example = header_component.dig('example', 'header_filename') || []
        doc_filename     = filename_example.first || 'file'
        { type: 'HEADER',
          parameters: [
            { type: 'document', document: { link: media_url, filename: doc_filename } }
          ] }
      when 'IMAGE'
        { type: 'HEADER',
          parameters: [
            { type: 'image', image: { link: media_url } }
          ] }
      when 'VIDEO'
        { type: 'HEADER',
          parameters: [
            { type: 'video', video: { link: media_url } }
          ] }
      end
    end

    def build_buttons_components(buttons_component)
      return [] unless buttons_component['buttons'].present?

      buttons_component['buttons'].each_with_index.map do |btn, idx|
        is_dynamic = btn['dynamic'] == true
        is_flow    = btn['type'] == 'FLOW'
        next unless is_dynamic || is_flow

        sub_type = determine_sub_type(btn)
        next unless sub_type

        params = build_button_parameters(sub_type, btn)
        next if params.blank?

        {
          type: 'BUTTON',
          sub_type: sub_type,
          index: idx.to_s,
          parameters: params
        }
      end.compact
    end

    def determine_sub_type(btn)
      case btn['type']
      when 'URL'          then 'url'
      when 'PHONE_NUMBER' then 'phone_number'
      when 'COPY_CODE'    then 'copy_code'
      when 'FLOW'         then 'flow'
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
        phone = btn['phone_number'].to_s.strip
        return [] if phone.empty?

        [{ type: 'text', text: phone }]
      when 'copy_code'
        code = btn.dig('example', 0).to_s.strip
        return [] if code.empty?

        [{ type: 'coupon_code', coupon_code: code }]
      when 'flow'
        flow_id = btn['flow_id']
        data    = btn['flow_action_data'] || {}
        [{
          type: 'action',
          action: { flow_token: flow_id.to_s, flow_action_data: data }
        }]
      else
        []
      end
    end

    # ---------- HTTP ------------------------------------------------
    def send_message(payload)
      url = "https://graph.facebook.com/#{version}/#{phone_number_id}/messages"
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }
      Faraday.post(url, payload.to_json, headers)
    rescue Faraday::Error => e
      raise StandardError, "Faraday error: #{e.message}"
    end

    # ---------- utils -----------------------------------------------
    def parse_json_body(body_str)
      return nil if body_str.blank?

      JSON.parse(body_str)
    rescue JSON::ParserError
      nil
    end
  end
end
