class MercadoLibre::SendOnMercadoLibreService < Base::SendOnChannelService
  private

  def channel_class
    Channel::MercadoLibre
  end

  def perform_reply
    case message.conversation.additional_attributes['type_of_conversation']
    when 'post_sale'
      channel.send_message_on_mercado_libre(message)
    when 'questions'
      channel.send_answer_on_mercado_libre(message)
    else
      raise StandardError, "Unknown type_of_conversation: #{message.conversation.additional_attributes['type_of_conversation']}"
    end
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end
end
