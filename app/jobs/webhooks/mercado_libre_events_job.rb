class Webhooks::MercadoLibreEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    user_id = params.dig("user_id") || params.dig(:mercado_libre, :user_id)
    return unless user_id && (channel = Channel::MercadoLibre.find_by(mercado_libre_user_id: user_id))

    case params["topic"]
    when "messages"
      process_message_event(channel, params)
    when "questions"
      process_question_event(channel, params)
    else
      log_invalid_event(params)
    end
  end

  private

  def process_message_event(channel, params)
    return log_invalid_event(params) unless valid_application_id?(params)

    inbox = find_or_create_inbox(channel, "Mensajes")
    return if message_already_processed?(params["resource"])

    MercadoLibre::IncomingMessageService.new(inbox: inbox, params: params).perform
  end

  def process_question_event(channel, params)
    return log_invalid_event(params) unless valid_application_id?(params)

    inbox = find_or_create_inbox(channel, "Preguntas")
    return if question_already_processed?(params["resource"])

    MercadoLibre::IncomingQuestionService.new(inbox: inbox, params: params).perform
  end

  def find_or_create_inbox(channel, type)
    inbox_name = "Mercado Libre - #{type}"
    channel.account.inboxes.find_or_create_by!(channel: channel, name: inbox_name)
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
    topic = params["topic"]
    Rails.logger.info "Invalid event: #{topic}. Params: #{params.inspect}"
  end
end
