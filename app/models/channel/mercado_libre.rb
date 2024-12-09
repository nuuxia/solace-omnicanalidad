# == Schema Information
#
# Table name: channel_mercado_libres
#
#  id                             :bigint           not null, primary key
#  mercado_libre_access_token     :string
#  mercado_libre_refresh_token    :string
#  mercado_libre_token_expires_at :datetime
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  mercado_libre_user_id          :integer
#
# Indexes
#
#  index_channel_mercado_libres_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Channel::MercadoLibre < ApplicationRecord
  include Channelable

  self.table_name = 'channel_mercado_libres'

  EDITABLE_ATTRS = [:mercado_libre_access_token, :mercado_libre_refresh_token, :mercado_libre_token_expires_at, :mercado_libre_user_id].freeze

  belongs_to :account

  validates :mercado_libre_access_token, uniqueness: true, presence: true
  validates :mercado_libre_refresh_token, presence: true
  validates :mercado_libre_token_expires_at, presence: true
  validates :mercado_libre_user_id, presence: true

  def name
    'Mercado Libre'
  end

  def token_expired?
    mercado_libre_token_expires_at < Time.current
  end

  def ensure_token_valid
    refresh_token if token_expired?
  end

  def send_message_on_mercado_libre(message)
    return send_message(message) if message.attachments.empty?

    # send_attachments(message)
  end

  private

  # def send_attachments(message)
  #   send_message(message) unless message.content.nil?

  #   mercado_libre_attachments = []
  #   byebug
  #   message.attachments.each do |attachment|
  #     byebug
  #     mercado_libre_attachment = {}
  #     mercado_libre_attachment[:file] = attachment.download_url
  #     mercado_libre_attachments << mercado_libre_attachment
  #   end
  #   byebug
  #   client = MercadoLibre::Client.new(mercado_libre_access_token)
  #   client.send_attachments_on_mercado_libre(mercado_libre_attachments)
  # end

  def send_message(message)
    ensure_token_valid

    message_request(message)
  end

  def message_request(message)
    conversation = message.conversation
    pack_id = conversation.additional_attributes['pack_id']
    seller_id = conversation.additional_attributes['seller_id']
    buyer_id = conversation.additional_attributes['buyer_id']
    text = message.content
    payload = reply_payload(seller_id, buyer_id, text)
    client = MercadoLibre::Client.new(mercado_libre_access_token)
    client.send_message_on_mercado_libre(payload, pack_id, seller_id, buyer_id, text)
  end

  def reply_payload(seller_id, buyer_id, text, attachments = [])
    {
      from: {
        user_id: seller_id.to_s
      },
      to: {
        user_id: buyer_id.to_s
      },
      text: text,
      attachments: attachments
    }.compact
  end

  def process_error(message, response)
    error_details = response.parsed_response['error'] || 'Unknown error'
    Rails.logger.error("Error sending message to Mercado Libre: #{error_details}")
    raise StandardError, "Failed to send message: #{error_details}"
  end

  def refresh_token
    token_service = MercadoLibre::RefreshTokenService.new(self)
    token_data = token_service.call

    update!(
      mercado_libre_access_token: token_data['access_token'],
      mercado_libre_refresh_token: token_data['refresh_token'],
      mercado_libre_token_expires_at: Time.current + token_data['expires_in'].seconds,
      mercado_libre_user_id: token_data['user_id']
    )
  end
end
