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
#  mercado_libre_user_id          :bigint
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

  EDITABLE_ATTRS = [:mercado_libre_access_token, :mercado_libre_refresh_token,
                    :mercado_libre_token_expires_at, :mercado_libre_user_id].freeze

  belongs_to :account

  validates :mercado_libre_access_token, uniqueness: true, presence: true
  validates :mercado_libre_refresh_token, :mercado_libre_token_expires_at,
            :mercado_libre_user_id, presence: true

  def name
    'Mercado Libre'
  end

  def token_expired?
    mercado_libre_token_expires_at < Time.current
  end

  def ensure_token_valid
    Rails.logger.info("[Channel::MercadoLibre] Verificando token para user_id #{mercado_libre_user_id}")
    refresh_token if token_expired?
  end

  def send_message_on_mercado_libre(message)
    process_and_send(:message, message)
  end

  def send_answer_on_mercado_libre(answer)
    process_and_send(:answer, answer)
  end

  private

  def process_and_send(type, resource)
    ensure_token_valid
    client = build_client

    case type
    when :message
      handle_message_request(resource, client)
    when :answer
      handle_answer_request(resource, client)
    end
  end

  def handle_message_request(message, client)
    conversation = fetch_conversation_data(message)
    payload = reply_payload(conversation[:seller_id], conversation[:buyer_id], message.content)
    client.send_message_on_mercado_libre(payload, conversation[:pack_id],
                                         conversation[:seller_id], conversation[:buyer_id], message.content)
  end

  def handle_answer_request(answer, client)
    conversation = answer.conversation
    last_incoming_message = last_incoming_message(conversation)

    if last_incoming_message.nil? || last_incoming_message.source_id.nil?
      Rails.logger.error "No valid incoming question found for conversation #{conversation.id}"
      return
    end

    payload = answer_payload(last_incoming_message.source_id, answer.content)
    client.send_answer_on_mercado_libre(payload)
  end

  def fetch_conversation_data(message)
    conversation = message.conversation
    {
      pack_id: conversation.additional_attributes['pack_id'],
      seller_id: conversation.additional_attributes['seller_id'],
      buyer_id: conversation.additional_attributes['buyer_id']
    }
  end

  def last_incoming_message(conversation)
    conversation.messages.incoming.last
  end

  def build_client
    MercadoLibre::Client.new(mercado_libre_access_token)
  end

  def reply_payload(seller_id, buyer_id, text, attachments = [])
    {
      from: { user_id: seller_id.to_s },
      to: { user_id: buyer_id.to_s },
      text: text,
      attachments: attachments
    }.compact
  end

  def answer_payload(question_id, text)
    { question_id: question_id, text: text }.compact
  end

  def refresh_token
    Rails.logger.info("[Channel::MercadoLibre] Refrescando token...")
    token_service = MercadoLibre::RefreshTokenService.new(self)
    token_data = token_service.call

    update!(
      mercado_libre_access_token: token_data['access_token'],
      mercado_libre_refresh_token: token_data['refresh_token'],
      mercado_libre_token_expires_at: Time.current + token_data['expires_in'].seconds,
      mercado_libre_user_id: token_data['user_id']
    )
    Rails.logger.info("[Channel::MercadoLibre] Token actualizado exitosamente")
  end
end
