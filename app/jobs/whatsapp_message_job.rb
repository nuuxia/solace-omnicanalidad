# app/workers/whatsapp_message_job.rb
class WhatsappMessageJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_messages, retry: 3

  RATE_LIMIT_KEY = 'whatsapp_rate_limit'
  MESSAGES_PER_SECOND = 10

  def perform(campaign_id, contact_id)
    Rails.logger.info "[WhatsappMessageJob] Iniciando envío para campaign=#{campaign_id}, contact=#{contact_id}"

    campaign = CampaignsWhatsapp.find(campaign_id)
    contact  = campaign.account.contacts.find(contact_id)

    if contact.phone_number.blank?
      Rails.logger.warn "[WhatsappMessageJob] Contacto #{contact_id} sin número de teléfono. Se salta el envío."
      return
    end

    enforce_rate_limit

    # 1) Tomar los campos “raw” que se guardaron en la campaña
    raw_template      = campaign.template
    body_vars         = campaign.body_variables || []
    button_vars       = campaign.button_variables || []
    header_media_url  = raw_template['header_media_url'] # guardada en create

    # 2) Expandir template con placeholders
    expanded_template = Whatsapp::TemplatePlaceholderService.new(
      template: raw_template,
      body_variables: body_vars,
      button_variables: button_vars,
      contact: contact,         # para contact_name
      header_media_url: header_media_url
    ).perform

    Rails.logger.info "[WhatsappMessageJob] Llamando a send_message para campaign=#{campaign_id}, contact=#{contact_id}"
    response_body = send_message(campaign, contact, expanded_template)

    if response_body.nil?
      Rails.logger.error '[WhatsappMessageJob] Respuesta nil. Error de red o parseo. Marcando como failed.'
      campaign.increment!(:messages_failed)
      return
    end

    log_response_details(response_body)

    if response_body.dig('messages', 0, 'message_status') == 'accepted'
      campaign.increment!(:messages_sent)
      Rails.logger.info "[WhatsappMessageJob] Mensaje enviado correctamente a #{contact.phone_number}"
    else
      campaign.increment!(:messages_failed)
      Rails.logger.error "[WhatsappMessageJob] Fallo al enviar mensaje a #{contact.phone_number}. Respuesta: #{response_body.inspect}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[WhatsappMessageJob] Registro no encontrado: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[WhatsappMessageJob] Error al enviar mensaje a contacto #{contact_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    campaign.increment!(:messages_failed) if defined?(campaign) && campaign.present?
    raise e
  end

  private

  def send_message(campaign, contact, expanded_template)
    api_key = campaign.inbox.whatsapp_api_key
    Rails.logger.info "[WhatsappMessageJob] Enviando mensaje a #{contact.phone_number} usando phone_number_id: #{campaign.inbox.phone_number_id}"

    Whatsapp::SendTemplateService.new(
      phone_number_id: campaign.inbox.phone_number_id,
      version: ENV.fetch('FB_GRAPH_API_VERSION', nil),  # o "v16.0"
      to: contact.phone_number,
      template: expanded_template,
      token: api_key
    ).perform
  end

  def enforce_rate_limit
    current_second = Time.now.to_i
    key = "#{RATE_LIMIT_KEY}:#{current_second}"

    count_response = nil
    Sidekiq.redis { |conn| count_response = conn.get(key) }
    count = count_response.to_i

    if count >= MESSAGES_PER_SECOND
      Rails.logger.warn "[enforce_rate_limit] Límite de #{MESSAGES_PER_SECOND} msg/seg alcanzado. Esperando 1s."
      sleep 1
      enforce_rate_limit
    else
      Sidekiq.redis do |conn|
        conn.multi do
          conn.incr(key)
          conn.expire(key, 2)
        end
      end
      Rails.logger.debug { "[enforce_rate_limit] Incrementado contador para #{key} a #{count + 1}" }
    end
  end

  def log_response_details(response_data)
    Rails.logger.info "\n===== Respuesta de la API de WhatsApp ====="
    Rails.logger.info "Response: #{response_data.inspect}"
    Rails.logger.info "=============================================\n"
  end
end