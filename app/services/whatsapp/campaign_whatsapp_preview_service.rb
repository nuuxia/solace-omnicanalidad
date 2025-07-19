# frozen_string_literal: true

module Whatsapp
  class CampaignWhatsappPreviewService
    attr_reader :account, :inbox_id, :phone_number, :template,
                :body_variables, :button_variables, :header_media_file

    def initialize(account:, inbox_id:, phone_number:, template:,
                   body_variables: [], button_variables: [], header_media_file: nil)
      @account            = account
      @inbox_id           = inbox_id
      @phone_number       = phone_number
      @template           = template
      @body_variables     = body_variables
      @button_variables   = button_variables
      @header_media_file  = header_media_file

      # Si los parámetros vienen como strings JSON, los parseamos
      @template = JSON.parse(@template) if @template.is_a?(String)
      @body_variables = JSON.parse(@body_variables) if @body_variables.is_a?(String)
      @button_variables = JSON.parse(@button_variables) if @button_variables.is_a?(String)

      @body_variable_values = []
    end

    def perform
      Rails.logger.info '[CampaignWhatsappPreviewService] Iniciando perform'

      validate_params
      process_placeholders
      upload_header_media_if_needed
      send_preview_message

      Rails.logger.info '[CampaignWhatsappPreviewService] Finalizando perform'
    end

    private

    def validate_params
      Rails.logger.info '[CampaignWhatsappPreviewService] Validando parámetros...'

      @inbox = account.inboxes.find(inbox_id)
      raise 'Invalid inbox type' unless @inbox.whatsapp?
      raise 'Invalid phone number' unless phone_number.match?(/^\+[0-9]+$/)
      raise 'Template is required' if template.blank?

      Rails.logger.info '[CampaignWhatsappPreviewService] Parámetros válidos'
    end

    def process_placeholders
      Rails.logger.info '[CampaignWhatsappPreviewService] Procesando placeholders de body y botones...'

      # BODY placeholders
      body_component = template_components.find { |c| c['type'] == 'BODY' }
      if body_component && body_component['text']
        placeholders = body_component['text'].scan(/{{(.*?)}}/)
        Rails.logger.info "[CampaignWhatsappPreviewService] Se encontraron #{placeholders.size} placeholders en el BODY"

        body_vars_enum = body_variables.each
        placeholders.each do |_placeholder|
          var_info = begin
            body_vars_enum.next
          rescue StandardError
            nil
          end
          @body_variable_values << if var_info.nil?
                                     ' '
                                   elsif var_info['sourceType'] == 'contact_name'
                                     fetch_contact_name_for(phone_number)
                                   elsif var_info['value'].to_s.strip.empty?
                                     ' '
                                   else
                                     var_info['value'].to_s
                                   end
        end
        Rails.logger.info "[CampaignWhatsappPreviewService] Valores resultantes para el body: #{@body_variable_values.inspect}"
      end

      # BUTTON placeholders
      buttons_component = template_components.find { |c| c['type'] == 'BUTTONS' }
      return unless buttons_component && buttons_component['buttons'].present?

      url_vars       = button_variables.select { |bv| bv['type'].to_s.upcase == 'URL' }
      copy_code_vars = button_variables.select { |bv| bv['type'].to_s.upcase == 'COPY_CODE' }
      phone_vars     = button_variables.select { |bv| bv['type'].to_s.upcase == 'PHONE_NUMBER' }

      new_buttons = buttons_component['buttons'].map do |btn|
        new_btn = btn.dup

        case new_btn['type']
        when 'URL'
          if /{{(.*?)}}/.match?(new_btn['url'].to_s)
            new_btn['dynamic'] = true
            var_info = url_vars.shift
            if var_info && var_info['value'].present?
              new_btn['example'] = [var_info['value'].to_s]
            else
              new_btn['example'] ||= ['Default URL']
            end
          else
            new_btn['dynamic'] = false
          end

        when 'PHONE_NUMBER'
          if /{{(.*?)}}/.match?(new_btn['phone_number'].to_s)
            new_btn['dynamic'] = true
            var_info = phone_vars.shift
            if var_info && var_info['value'].present?
              new_btn['phone_number'] = new_btn['phone_number'].gsub(/{{(.*?)}}/, var_info['value'].to_s)
            else
              new_btn['dynamic'] = false
              new_btn['phone_number'] = new_btn['phone_number'].gsub(/{{(.*?)}}/, '')
            end
          else
            new_btn['dynamic'] = false
          end

        when 'COPY_CODE'
          if new_btn['example'].present?
            var_info = copy_code_vars.shift
            new_btn['example'] = [var_info['value'].to_s] if var_info && var_info['value'].present?
            new_btn['dynamic'] = true
          end

        when 'FLOW'
          # NUEVO: Para un botón de tipo FLOW,
          # se asume que en este punto no hay placeholders (o si los hay, igual
          # podrías hacer algo parecido a 'URL'). Por simplicidad:
          new_btn['dynamic'] = false

        else
          # Otros tipos no contemplados
        end

        new_btn
      end

      buttons_component['buttons'] = new_buttons
      Rails.logger.info "[CampaignWhatsappPreviewService] Botones procesados: #{new_buttons.inspect}"
    end

    def upload_header_media_if_needed
      header_component = template_components.find { |c| c['type'] == 'HEADER' }
      return unless header_component

      format = header_component['format']
      return unless %w[IMAGE VIDEO DOCUMENT].include?(format)
      return unless header_media_file

      Rails.logger.info "[CampaignWhatsappPreviewService] Subiendo archivo de cabecera (#{format})..."

      url = Whatsapp::CampaignWhatsappFileUploadService.new(header_media_file).perform
      header_component['example'] ||= {}
      header_component['example']['header_handle'] = [url]

      header_component['example']['header_filename'] = [header_media_file.original_filename] if format == 'DOCUMENT'

      Rails.logger.info "[CampaignWhatsappPreviewService] Archivo subido. URL: #{url}"
    end

    def send_preview_message
      Rails.logger.info '[CampaignWhatsappPreviewService] Enviando mensaje de vista previa...'

      template['_cloudapi_body_params'] = @body_variable_values
      Whatsapp::SendTemplateService.new(
        phone_number_id: @inbox.phone_number_id,
        version: ENV.fetch('FB_GRAPH_API_VERSION', nil),
        to: phone_number,
        template: template,
        token: @inbox.whatsapp_api_key
      ).perform
    end

    def template_components
      template['components'] || []
    end

    def fetch_contact_name_for(phone)
      contact = Contact.find_by(account_id: account.id, phone_number: phone)
      contact && contact.name.present? ? contact.name : phone
    end
  end
end