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
      Rails.logger.info "[CampaignWhatsappPreviewService] Iniciando perform"

      validate_params
      process_placeholders
      upload_header_media_if_needed
      send_preview_message

      Rails.logger.info "[CampaignWhatsappPreviewService] Finalizando perform"
    end

    private

    def validate_params
      Rails.logger.info "[CampaignWhatsappPreviewService] Validando parámetros..."

      @inbox = account.inboxes.find(inbox_id)
      raise 'Invalid inbox type' unless @inbox.whatsapp?
      raise 'Invalid phone number' unless phone_number.match?(/^\+[0-9]+$/)
      raise 'Template is required' if template.blank?

      Rails.logger.info "[CampaignWhatsappPreviewService] Parámetros válidos"
    end

    # Procesa los placeholders para el BODY y ajusta los BOTONES según corresponda.
    def process_placeholders
      Rails.logger.info "[CampaignWhatsappPreviewService] Procesando placeholders de body y botones..."

      # --- BODY ---
      body_component = template_components.find { |c| c['type'] == 'BODY' }
      if body_component && body_component['text']
        placeholders = body_component['text'].scan(/{{(.*?)}}/)
        Rails.logger.info "[CampaignWhatsappPreviewService] Se encontraron #{placeholders.size} placeholders en el cuerpo"

        body_vars_enum = body_variables.each
        placeholders.each do |_placeholder|
          var_info = (body_vars_enum.next rescue nil)
          if var_info.nil?
            @body_variable_values << ' '
          elsif var_info['sourceType'] == 'contact_name'
            # Siempre busca el nombre del contacto, sin importar el valor enviado
            @body_variable_values << fetch_contact_name_for(phone_number)
          elsif var_info['value'].to_s.strip.empty?
            @body_variable_values << ' '
          else
            @body_variable_values << var_info['value'].to_s
          end
        end
        Rails.logger.info "[CampaignWhatsappPreviewService] Valores resultantes para el body: #{@body_variable_values.inspect}"
      end

      # --- BOTONES ---
      buttons_component = template_components.find { |c| c['type'] == 'BUTTONS' }
      return unless buttons_component && buttons_component['buttons'].present?

      # Agrupar las variables de botones por tipo (según el valor de "type")
      url_vars       = button_variables.select { |bv| bv['type'].to_s.upcase == 'URL' }
      copy_code_vars = button_variables.select { |bv| bv['type'].to_s.upcase == 'COPY_CODE' }
      phone_vars     = button_variables.select { |bv| bv['type'].to_s.upcase == 'PHONE_NUMBER' }

      new_buttons = buttons_component['buttons'].map.with_index do |btn, index|
        new_btn = btn.dup
        case new_btn['type']
        when 'URL'
          if new_btn['url'].to_s.match(/{{(.*?)}}/)
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
          if new_btn['phone_number'].to_s.match(/{{(.*?)}}/)
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
            if var_info && var_info['value'].present?
              new_btn['example'] = [var_info['value'].to_s]
            end
            new_btn['dynamic'] = true
          end
        else
          # No se realiza modificación para otros tipos
        end
        new_btn
      end

      buttons_component['buttons'] = new_buttons
      Rails.logger.info "[CampaignWhatsappPreviewService] Botones procesados: #{new_buttons.inspect}"
    end

    # Sube el archivo de cabecera si el template tiene un componente HEADER con formato IMAGE, VIDEO o DOCUMENT.
    def upload_header_media_if_needed
      header_component = template_components.find { |c| c['type'] == 'HEADER' }
      return unless header_component

      format = header_component['format']
      return unless %w[IMAGE VIDEO DOCUMENT].include?(format)
      return unless header_media_file

      Rails.logger.info "[CampaignWhatsappPreviewService] Subiendo archivo de cabecera (#{format})..."

      url = Whatsapp::CampaignPreviewFileUploadService.new(header_media_file).perform
      header_component['example'] ||= {}
      header_component['example']['header_handle'] = [url]

      if format == 'DOCUMENT'
        header_component['example']['header_filename'] = [header_media_file.original_filename]
      end

      Rails.logger.info "[CampaignWhatsappPreviewService] Archivo subido. URL: #{url}"
    end

    # Envía el mensaje de vista previa usando el SendTemplateService
    def send_preview_message
      Rails.logger.info "[CampaignWhatsappPreviewService] Enviando mensaje de vista previa..."

      # Asigna los valores procesados del body a la llave esperada por el payload de la API
      template['_cloudapi_body_params'] = @body_variable_values

      Whatsapp::SendTemplateService.new(
        phone_number_id: @inbox.phone_number_id,
        version: ENV['VITE_FB_GRAPH_API_VERSION'],
        to: phone_number,
        template: template,
        token: @inbox.whatsapp_api_key
      ).perform
    end

    def template_components
      template['components'] || []
    end

    # Busca el contacto por número y retorna el nombre; si no se encuentra, retorna el teléfono
    def fetch_contact_name_for(phone)
      contact = Contact.find_by(account_id: account.id, phone_number: phone)
      contact && contact.name.present? ? contact.name : phone
    end
  end
end
