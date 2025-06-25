# frozen_string_literal: true

require 'uri'

module Whatsapp
  class TemplatePlaceholderService
    attr_reader :template, :body_variables, :button_variables,
                :contact, :row

    # • row es opcional: solo lo pasan las campañas CSV
    def initialize(template:, body_variables: [], button_variables: [],
                   contact: nil, header_media_url: nil, row: nil)
      @template         = template.deep_dup || {}
      @body_variables   = body_variables
      @button_variables = button_variables
      @contact          = contact
      @header_media_url = header_media_url
      @row              = row || {}
    end

    def perform
      process_placeholders
      attach_header_media if @header_media_url.present?
      template
    end

    private

    # ------------------------------------------------------------------
    # 1) BODY placeholders
    # ------------------------------------------------------------------
    def process_placeholders
      body_component = template_components.find { |c| c['type'] == 'BODY' }
      handle_body_placeholders(body_component) if body_component&.dig('text')

      # ----------------------------------------------------------------
      # 2) BUTTONS placeholders (sin cambios respecto al original)
      # ----------------------------------------------------------------
      buttons_component = template_components.find { |c| c['type'] == 'BUTTONS' }
      return unless buttons_component && buttons_component['buttons'].present?

      url_vars       = button_variables.select { |bv| bv['type'].to_s.upcase == 'URL' }
      copy_code_vars = button_variables.select { |bv| bv['type'].to_s.upcase == 'COPY_CODE' }
      phone_vars     = button_variables.select { |bv| bv['type'].to_s.upcase == 'PHONE_NUMBER' }

      buttons_component['buttons'] = buttons_component['buttons'].map do |btn|
        build_dynamic_button(btn, url_vars, phone_vars, copy_code_vars)
      end
    end

    # ---------- BODY helpers ---------------------------------------------------
    def handle_body_placeholders(body_component)
      placeholders     = body_component['text'].scan(/{{(.*?)}}/)
      replaced_values  = []
      var_enum         = body_variables.each

      placeholders.each do
        var_info = begin
          var_enum.next
        rescue StandardError
          nil
        end

        # 1. Sin variable -> espacio
        if var_info.nil?
          replaced_values << ' '
          next
        end

        # 2. contact_name especial
        if var_info['sourceType'] == 'contact_name' && contact
          replaced_values << (contact.name.presence || contact.phone_number)
          next
        end

        # 3. valor explícito
        value = var_info['value'].presence

        # 4. Si value vacío, intenta leer columna CSV (solo campañas CSV)
        if value.blank? && row.present? && var_info['sourceType'].present?
          key   = var_info['sourceType']
          value = row[key.to_sym] || row[key.to_s]
        end

        replaced_values << (value.presence || ' ')
      end

      # Sustituir en el texto final
      i = 0
      body_component['text'] = body_component['text'].gsub(/{{(.*?)}}/) do
        replaced_values[i].to_s.tap { i += 1 }
      end

      # Cloud API – params para el cuerpo
      template['_cloudapi_body_params'] = replaced_values
    end

    # ---------- BUTTONS helpers ------------------------------------------------
    def build_dynamic_button(btn, url_vars, phone_vars, copy_code_vars)
      new_btn = btn.dup
      case new_btn['type']
      when 'URL'
        if /{{(.*?)}}/.match?(new_btn['url'].to_s)
          new_btn['dynamic'] = true
          var_info = url_vars.shift
          if var_info&.dig('value').present?
            new_btn['url']     = new_btn['url'].gsub(/{{(.*?)}}/, var_info['value'])
            new_btn['example'] = [new_btn['url']]
          else
            new_btn['example'] = ['Default URL']
          end
        else
          new_btn['dynamic'] = false
        end
      when 'PHONE_NUMBER'
        if /{{(.*?)}}/.match?(new_btn['phone_number'].to_s)
          new_btn['dynamic'] = true
          var_info = phone_vars.shift
          replacement = var_info&.dig('value').presence || ''
          new_btn['phone_number'] = new_btn['phone_number'].gsub(/{{(.*?)}}/, replacement)
          new_btn['example']      = [new_btn['phone_number']] if new_btn['dynamic']
        else
          new_btn['dynamic'] = false
        end
      when 'COPY_CODE'
        if new_btn['example'].present?
          new_btn['dynamic'] = true
          var_info = copy_code_vars.shift
          new_btn['example'] = [var_info['value'].to_s] if var_info&.dig('value').present?
        end
      end
      new_btn
    end

    # ---------- HEADER helpers -------------------------------------------------
    def attach_header_media
      header_comp = template_components.find { |c| c['type'] == 'HEADER' }
      return unless header_comp

      format = header_comp['format']
      return unless %w[IMAGE VIDEO DOCUMENT].include?(format)

      header_comp['example'] ||= {}
      header_comp['example']['header_handle'] = [@header_media_url]

      return unless format == 'DOCUMENT'

      uri   = URI.parse(@header_media_url)
      fname = File.basename(uri.path)
      header_comp['example']['header_filename'] = [fname]
    end

    def template_components
      template['components'] || []
    end
  end
end
