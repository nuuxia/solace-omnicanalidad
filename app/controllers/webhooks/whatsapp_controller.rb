class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  def process_payload
    if inactive_whatsapp_number?
      Rails.logger.warn("Rejected webhook for inactive WhatsApp number: #{params[:phone_number]}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    if contains_echo_event?(params.to_unsafe_hash)
      # Add delay to prevent race condition where echo arrives before send message API completes
      # This avoids duplicate messages when echo comes early during API processing
      Webhooks::WhatsappEventsJob.set(wait: 2.seconds).perform_later(params.to_unsafe_hash)
    else
      Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash)
    end

    head :ok
  end

  private

  def contains_echo_event?(params)
    return false unless params[:entry].is_a?(Array)

    params[:entry].any? do |entry|
      # Check changes array for message_echoes events
      changes = entry[:changes] || []
      changes.any? do |change|
        change[:field] == 'smb_message_echoes' &&
          change.dig(:value, :message_echoes).present?
      end
    end
  end

  def valid_token?(token)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  def inactive_whatsapp_number?
    phone_number = params[:phone_number]
    return false if phone_number.blank?

    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s
    return false if inactive_numbers.blank?

    inactive_numbers_array = inactive_numbers.split(',').map(&:strip)
    inactive_numbers_array.include?(phone_number)
  end
end
