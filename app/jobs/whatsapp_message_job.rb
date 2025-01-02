class WhatsappMessageJob
    include Sidekiq::Worker
    sidekiq_options queue: :whatsapp_messages, retry: 3
    RATE_LIMIT_KEY = "whatsapp_rate_limit"
    MESSAGES_PER_SECOND = 10
    def perform(campaign_id, contact_id)
      campaign = nil # Inicializar la variable
      Rails.logger.info "📤 [WhatsappMessageJob] Processing message for campaign=#{campaign_id}, contact=#{contact_id}"
      
      begin
        campaign = CampaignsWhatsapp.find(campaign_id)
        contact = campaign.account.contacts.find(contact_id)
        
        if contact.phone_number.blank?
          Rails.logger.warn "[WhatsappMessageJob] Contact #{contact_id} has no phone number. Skipping."
          return
        end
        enforce_rate_limit
        response = send_message(campaign, contact)
        log_response_details(response)
        
        # Verificar el estado del mensaje en la respuesta de la API
        if response['messages'] && response['messages'].first['message_status'] == 'accepted'
          campaign.increment!(:messages_sent)
          Rails.logger.info "✅ [WhatsappMessageJob] Message sent to #{contact.phone_number} successfully."
        else
          campaign.increment!(:messages_failed)
          Rails.logger.error "[WhatsappMessageJob] Failed to send message to #{contact.phone_number}. Response: #{response.inspect}"
        end
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "[WhatsappMessageJob] Record not found: #{e.message}"
        # Opcional: Notificar al equipo o registrar información adicional
      rescue StandardError => e
        Rails.logger.error "[WhatsappMessageJob] Error sending message to contact #{contact_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        campaign.increment!(:messages_failed) if campaign
        raise e
      end
    end
    private
    
    def send_message(campaign, contact)
      Whatsapp::SendTemplateService.new(
        phone_number_id: campaign.inbox.phone_number_id,
        version: ENV['VITE_FB_GRAPH_API_VERSION'],
        to: contact.phone_number,
        template: campaign.template
      ).perform
    end
    def enforce_rate_limit
      redis = Sidekiq.redis { |conn| conn }
      current_second = Time.now.to_i
      key = "#{RATE_LIMIT_KEY}:#{current_second}"
      
      count_response = redis.get(key)
      
      # Añadir registro de depuración
      Rails.logger.debug "[enforce_rate_limit] Redis.get('#{key}') returned: #{count_response.inspect}"
      
      # Manejar diferentes tipos de respuesta
      if count_response.is_a?(String) || count_response.is_a?(Numeric)
        count = count_response.to_i
      else
        Rails.logger.error "[enforce_rate_limit] Unexpected response type from Redis.get: #{count_response.class} - #{count_response.inspect}"
        count = 0
      end
    
      if count >= MESSAGES_PER_SECOND
        Rails.logger.warn "[enforce_rate_limit] Rate limit reached for key=#{key}. Sleeping for 1 segundo."
        sleep 1
        enforce_rate_limit
      else
        redis.multi do
          redis.incr(key)
          redis.expire(key, 2)
        end
        Rails.logger.debug "[enforce_rate_limit] Incremented count for key=#{key} to #{count + 1}."
      end
    end
    def log_response_details(response)
      Rails.logger.info "\n===== WhatsApp API Response ====="
      Rails.logger.info "Response: #{response.inspect}"
      Rails.logger.info "===============================\n"
    end
    def log_error_details(error)
      Rails.logger.error "\n===== WhatsApp API Error ====="
      Rails.logger.error "Error Message: #{error.message}"
      Rails.logger.error "Backtrace: #{error.backtrace.join("\n")}"
      Rails.logger.error "=============================\n"
    end
  end