class Webhooks::MercadoLibreEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    user_id = params.dig("user_id") || params.dig(:mercado_libre, :user_id)
    return unless user_id && (channel = Channel::MercadoLibre.find_by(mercado_libre_user_id: user_id))
    process_event_params(channel, params)
  end

  private

  def process_event_params(channel, params)
    if valid_application_id?(params) && params["topic"] == "messages" && !message_already_processed?(params["resource"])
      MercadoLibre::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
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

  def log_invalid_event(params)
    if params["topic"] != "messages"
      Rails.logger.info "Message already processed or topic is not 'messages'."
    else
      Rails.logger.error "Webhook application_id does not match the expected value."
    end
  end

end
