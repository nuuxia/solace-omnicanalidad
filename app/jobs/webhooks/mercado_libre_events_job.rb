class Webhooks::MercadoLibreEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    Rails.logger.info("[WebhookJob] Procesando evento con params: #{params.inspect}")

    user_id = params.dig("user_id") || params.dig(:mercado_libre, :user_id)
    unless user_id
      Rails.logger.warn("[WebhookJob] No se encontró user_id en params: #{params.inspect}")
      return
    end

    channel = Channel::MercadoLibre.find_by(mercado_libre_user_id: user_id)
    unless channel
      Rails.logger.warn("[WebhookJob] No se encontró channel para user_id: #{user_id}")
      return
    end

    inbox = channel.inbox
    unless inbox
      Rails.logger.warn("[WebhookJob] No se encontró inbox para channel: #{channel.id}")
      return
    end

    topic = params["topic"]
    resource_id = params["resource"]
    unless resource_id.present?
      Rails.logger.warn("[WebhookJob] resource_id vacío para topic #{topic}")
      return
    end

    Rails.logger.info("[WebhookJob] Topic: #{topic}, resource: #{resource_id}")

    case topic
    when "messages"
      Rails.logger.info("[WebhookJob] Procesando evento de mensajes")
      process_message_event(inbox, params) if inbox.mercado_libre_post_sale_messages?
    when "questions"
      Rails.logger.info("[WebhookJob] Procesando evento de preguntas")
      process_question_event(inbox, params) if inbox.mercado_libre_pre_sale_questions?
    else
      log_invalid_event(params)
    end
  end

  private

  def process_message_event(inbox, params)
    Rails.logger.info("[WebhookJob] Validando application_id: recibido=#{params['application_id']} vs esperado=#{ENV['MERCADO_LIBRE_APP_ID']}")
    if valid_application_id?(params)
      Rails.logger.info("[WebhookJob] Application ID válido. Llamando a IncomingMessageService.")
      MercadoLibre::IncomingMessageService.new(inbox: inbox, params: params).perform
    else
      Rails.logger.warn("[WebhookJob] Application ID inválido. Ignorando mensaje.")
      log_invalid_event(params)
    end
  end


  def process_question_event(inbox, params)
    Rails.logger.info("[WebhookJob] Validando application_id: recibido=#{params['application_id']} vs esperado=#{ENV['MERCADO_LIBRE_APP_ID']}")
    if valid_application_id?(params)
      Rails.logger.info("[WebhookJob] Application ID válido. Llamando a IncomingQuestionService.")
      MercadoLibre::IncomingQuestionService.new(inbox: inbox, params: params).perform
    else
      Rails.logger.warn("[WebhookJob] Application ID inválido. Ignorando pregunta.")
      log_invalid_event(params)
    end
  end

  def valid_application_id?(params)
    params["application_id"].to_s == ENV["MERCADO_LIBRE_APP_ID"].to_s
  end

  def log_invalid_event(params)
    Rails.logger.info "Webhook ignored: #{params.inspect}"
  end
end
