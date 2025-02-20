class Webhooks::MercadoLibreEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    user_id = params.dig("user_id") || params.dig(:mercado_libre, :user_id)
    return unless user_id && (channel = Channel::MercadoLibre.find_by(mercado_libre_user_id: user_id))

    inbox = channel.inbox
    return unless inbox

    case params["topic"]
    when "messages"
      process_message_event(channel, params) if inbox.mercado_libre_post_sale_messages?
    when "questions"
      process_question_event(channel, params) if inbox.mercado_libre_pre_sale_questions?
    else
      log_invalid_event(params)
    end
  end

  private

  def process_message_event(channel, params)
    if valid_application_id?(params) && !message_already_processed?(params["resource"])
      MercadoLibre::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    else
      log_invalid_event(params)
    end
  end

  def process_question_event(channel, params)
    if valid_application_id?(params) && !question_already_processed?(params["resource"])
      MercadoLibre::IncomingQuestionService.new(inbox: channel.inbox, params: params).perform
    else
      log_invalid_event(params)
    end
  end

  def valid_application_id?(params)
    params["application_id"].to_s == ENV["MERCADO_LIBRE_APP_ID"].to_s
  end

  def message_already_processed?(resource_id)
    Message.exists?(source_id: resource_id)
  end

  def question_already_processed?(resource_id)
    Message.exists?(source_id: resource_id)
  end

  def log_invalid_event(params)
    case params["topic"]
    when "messages"
      Rails.logger.info "Message already processed or topic is not 'messages'."
    when "questions"
      Rails.logger.info "Question already processed or topic is not 'questions'."
    else
      Rails.logger.error "Webhook application_id does not match the expected value or topic is invalid."
    end
  end
end
