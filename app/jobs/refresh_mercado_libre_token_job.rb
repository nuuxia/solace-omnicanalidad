# app/jobs/refresh_mercado_libre_token_job.rb
class RefreshMercadoLibreTokenJob < ApplicationJob
  queue_as :default
  def perform(channel_id)
    channel = ChannelMercadoLibre.find(channel_id)
    return unless channel.mercado_libre_token_expires_at < Time.current
    refresh_service = MercadoLibre::RefreshTokenService.new(channel)
    token_data = refresh_service.call
    channel.update!(
      mercado_libre_access_token: token_data['access_token'],
      mercado_libre_refresh_token: token_data['refresh_token'],
      mercado_libre_token_expires_at: Time.current + 6.hours,
      mercado_libre_user_id: token_data['user_id']
    )
  end
end
