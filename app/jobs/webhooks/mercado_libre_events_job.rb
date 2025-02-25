class Webhooks::MercadoLibreEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    user_id = params.dig("user_id") || params.dig(:mercado_libre, :user_id)
    return unless user_id && (channel = Channel::MercadoLibre.find_by(mercado_libre_user_id: user_id))

    inbox = channel.inbox
    return unless inbox

    resource_id = params["resource"]
    topic = params["topic"]
    return unless resource_id.present? # Asegurarse de que el resource_id no sea nil o vacío

    cache_key = "webhook_lock:#{topic}:#{resource_id}"

    # Usar fetch para evitar problemas de concurrencia y hacer el bloqueo más seguro
    return if Rails.cache.fetch(cache_key, expires_in: 10.seconds) { true } == true

    case topic
    when "messages"
      process_message_event(inbox, params) if inbox.mercado_libre_post_sale_messages?
    when "questions"
      process_question_event(inbox, params) if inbox.mercado_libre_pre_sale_questions?
    else
      log_invalid_event(params)
    end
  end

  private

  def process_message_event(inbox, params)
    if valid_application_id?(params)
      MercadoLibre::IncomingMessageService.new(inbox: inbox, params: params).perform
    else
      log_invalid_event(params)
    end
  end

  def process_question_event(inbox, params)
    if valid_application_id?(params)
      MercadoLibre::IncomingQuestionService.new(inbox: inbox, params: params).perform
    else
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
