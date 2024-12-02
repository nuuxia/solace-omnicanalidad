class MercadoLibre::SendOnMercadoLibreService < Base::SendOnChannelService
  private
  def channel_class
    Channel::MercadoLibre
  end
  def perform_reply
    channel.send_message_on_mercado_libre(message)
  end
  def inbox
    @inbox ||= message.inbox
  end
  def channel
    @channel ||= inbox.channel
  end
end
