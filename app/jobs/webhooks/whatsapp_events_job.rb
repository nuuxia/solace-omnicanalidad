class Webhooks::WhatsappEventsJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    Rails.logger.info("[Webhooks::WhatsappEventsJob] INICIO perform. params[:entry]=#{params[:entry].inspect}")
    channel = find_channel_from_whatsapp_business_payload(params)

    if channel_is_inactive?(channel)
      Rails.logger.warn("Inactive WhatsApp channel: #{channel&.phone_number || "unknown - #{params[:phone_number]}"}")
      return
    end

    Rails.logger.info("[Webhooks::WhatsappEventsJob] Channel encontrado: phone_number=#{channel.phone_number}, inbox_id=#{channel.inbox.id}")

    # Check if this is a message from a coexistent device
    if message_from_coexistent_device?(params, channel)
      Rails.logger.info('[Webhooks::WhatsappEventsJob] Detectado mensaje coexistente. Llamando a Whatsapp::CoexistenceMessageService')
      Whatsapp::CoexistenceMessageService.new(inbox: channel.inbox, params: params).perform
      return
    end

    Rails.logger.info('[Webhooks::WhatsappEventsJob] No es mensaje coexistente. Usando servicio normal.')
    case channel.provider
    when 'whatsapp_cloud'
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: channel.inbox, params: params).perform
    else
      Whatsapp::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    end
  end

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end

  def find_channel_by_url_param(params)
    Rails.logger.info("[Webhooks::WhatsappEventsJob] find_channel_by_url_param - params[:phone_number]=#{params[:phone_number]}")
    return unless params[:phone_number]

    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    Rails.logger.info("[Webhooks::WhatsappEventsJob] find_channel_by_url_param - channel encontrado: #{channel&.id}")
    channel
  end

  def find_channel_from_whatsapp_business_payload(params)
    Rails.logger.info("[Webhooks::WhatsappEventsJob] find_channel_from_whatsapp_business_payload - params[:object]=#{params[:object]}")

    # for the case where facebook cloud api support multiple numbers for a single app
    # https://github.com/chatwoot/chatwoot/issues/4712#issuecomment-1173838350
    # we will give priority to the phone_number in the payload
    if params[:object] == 'whatsapp_business_account'
      Rails.logger.info('[Webhooks::WhatsappEventsJob] Usando get_channel_from_wb_payload')
      return get_channel_from_wb_payload(params)
    end

    Rails.logger.info('[Webhooks::WhatsappEventsJob] Usando find_channel_by_url_param')
    find_channel_by_url_param(params)
  end

  def get_channel_from_wb_payload(wb_params)
    phone_number = "+#{wb_params[:entry].first[:changes].first.dig(:value, :metadata, :display_phone_number)}"
    phone_number_id = wb_params[:entry].first[:changes].first.dig(:value, :metadata, :phone_number_id)

    Rails.logger.info("[Webhooks::WhatsappEventsJob] get_channel_from_wb_payload - phone_number=#{phone_number}, phone_number_id=#{phone_number_id}")

    channel = Channel::Whatsapp.find_by(phone_number: phone_number)
    Rails.logger.info("[Webhooks::WhatsappEventsJob] get_channel_from_wb_payload - channel encontrado: #{channel&.id}")

    # validate to ensure the phone number id matches the whatsapp channel
    if channel && channel.provider_config['phone_number_id'] == phone_number_id
      Rails.logger.info('[Webhooks::WhatsappEventsJob] get_channel_from_wb_payload - phone_number_id coincide')
      return channel
    else
      Rails.logger.warn("[Webhooks::WhatsappEventsJob] get_channel_from_wb_payload - phone_number_id NO coincide. channel_config=#{channel&.provider_config&.[]('phone_number_id')}, payload_id=#{phone_number_id}")
      return nil
    end
  end

  def message_from_coexistent_device?(params, channel)
    Rails.logger.info('[Webhooks::WhatsappEventsJob] message_from_coexistent_device? - Verificando coexistencia...')
    return false unless channel.present?
    return false unless params[:entry].present? && params[:entry].first[:changes].present?

    # Get the message data from either message_echoes or messages
    value = params[:entry].first[:changes].first.dig(:value)
    message_data = value[:message_echoes]&.first || value[:messages]&.first

    if message_data.blank?
      Rails.logger.info('[Webhooks::WhatsappEventsJob] message_from_coexistent_device? - No hay message_data en el payload')
      return false
    end

    # Check if the sender is the same as the channel's phone number (without the '+' prefix)
    sender = message_data[:from]
    channel_number = channel.phone_number.delete('+')

    Rails.logger.info("[Webhooks::WhatsappEventsJob] message_from_coexistent_device? - sender=#{sender}, channel_number=#{channel_number}")

    # If the sender is the same as the channel's number, it's from a coexistent device
    # This means the message was sent from another WhatsApp device connected to the same account
    result = sender == channel_number
    Rails.logger.info("[Webhooks::WhatsappEventsJob] message_from_coexistent_device? - result=#{result}")
    result
  end
end
