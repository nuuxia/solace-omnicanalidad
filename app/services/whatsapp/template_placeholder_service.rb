# app/services/whatsapp/template_placeholder_service.rb
require 'uri'
module Whatsapp
    class TemplatePlaceholderService
      attr_reader :template, :body_variables, :button_variables, :contact
  
      # contact es opcional, pero se utiliza si un placeholder es "contact_name"
      def initialize(template:, body_variables: [], button_variables: [], contact: nil, header_media_url: nil)
        @template         = template.deep_dup || {}
        @body_variables   = body_variables
        @button_variables = button_variables
        @contact          = contact
        @header_media_url = header_media_url
      end
  
      def perform
        process_placeholders
        attach_header_media if @header_media_url.present?
        template
      end
  
      private
  
      def process_placeholders
        # 1) BODY
        body_component = template_components.find { |c| c['type'] == 'BODY' }
        if body_component && body_component['text']
          placeholders = body_component['text'].scan(/{{(.*?)}}/)
          replaced_values = []
          var_enum = body_variables.each
  
          placeholders.each do |_ph|
            var_info = (var_enum.next rescue nil)
            if var_info.nil?
              replaced_values << ' '
            elsif var_info['sourceType'] == 'contact_name' && @contact
              replaced_values << (contact.name.presence || contact.phone_number)
            else
              replaced_values << (var_info['value'].presence || ' ')
            end
          end
  
          i = 0
          body_component['text'] = body_component['text'].gsub(/{{(.*?)}}/) do
            replaced_values[i].to_s.tap { i += 1 }
          end
  
          # Para que SendTemplateService sepa qué params lleva el body
          template['_cloudapi_body_params'] = replaced_values
        end
  
        # 2) BUTTONS
        buttons_component = template_components.find { |c| c['type'] == 'BUTTONS' }
        return unless buttons_component && buttons_component['buttons'].present?
  
        url_vars       = button_variables.select { |bv| bv['type'].to_s.upcase == 'URL' }
        copy_code_vars = button_variables.select { |bv| bv['type'].to_s.upcase == 'COPY_CODE' }
        phone_vars     = button_variables.select { |bv| bv['type'].to_s.upcase == 'PHONE_NUMBER' }
  
        new_buttons = buttons_component['buttons'].map do |btn|
          new_btn = btn.dup
          case new_btn['type']
          when 'URL'
            if new_btn['url'].to_s.match(/{{(.*?)}}/)
              new_btn['dynamic'] = true
              var_info = url_vars.shift
              if var_info&.dig('value').present?
                new_btn['url'] = new_btn['url'].gsub(/{{(.*?)}}/, var_info['value'])
                new_btn['example'] = [new_btn['url']]
              else
                new_btn['example'] = ["Default URL"]
              end
            else
              new_btn['dynamic'] = false
            end
          when 'PHONE_NUMBER'
            if new_btn['phone_number'].to_s.match(/{{(.*?)}}/)
              new_btn['dynamic'] = true
              var_info = phone_vars.shift
              if var_info&.dig('value').present?
                new_btn['phone_number'] = new_btn['phone_number'].gsub(/{{(.*?)}}/, var_info['value'])
              else
                new_btn['phone_number'] = new_btn['phone_number'].gsub(/{{(.*?)}}/, '')
              end
              new_btn['example'] = [new_btn['phone_number']] if new_btn['dynamic']
            else
              new_btn['dynamic'] = false
            end
          when 'COPY_CODE'
            if new_btn['example'].present?
              new_btn['dynamic'] = true
              var_info = copy_code_vars.shift
              if var_info&.dig('value').present?
                new_btn['example'] = [var_info['value'].to_s]
              end
            end
          else
            # no se modifica
          end
          new_btn
        end
  
        buttons_component['buttons'] = new_buttons
      end
  
      def attach_header_media
        header_comp = template_components.find { |c| c['type'] == 'HEADER' }
        return unless header_comp
        format = header_comp['format']
        return unless %w[IMAGE VIDEO DOCUMENT].include?(format)
  
        header_comp['example'] ||= {}
        header_comp['example']['header_handle'] = [@header_media_url]
  
        if format == 'DOCUMENT'
          # Parseamos la URL y nos quedamos solo con el nombre, sin parámetros
          uri   = URI.parse(@header_media_url)
          fname = File.basename(uri.path)   # => "text_example.pdf"
        
          header_comp['example'] ||= {}
          header_comp['example']['header_filename'] = [fname]
        end
      end
  
      def template_components
        template['components'] || []
      end
    end
  end
  