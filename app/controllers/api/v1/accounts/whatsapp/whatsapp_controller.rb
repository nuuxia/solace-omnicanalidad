class Api::V1::Accounts::Whatsapp::WhatsappController < ApplicationController
    before_action :set_account
  
    def sync_whatsapp_templates
      Rails.logger.info "🕵🏻‍♀️ Buscando cuenta con ID: #{params[:account_id]}"
      Rails.logger.info "🔎✨ [sync_whatsapp_templates] Iniciando la sincronización de plantillas para la cuenta: #{@account.id}"
  
      whatsapp_channels = @account.whatsapp_channels
  
      if whatsapp_channels.any?
        errors = []
  
        whatsapp_channels.each do |whatsapp_channel|
          Rails.logger.info "⚙️ Procesando WhatsAppChannel con ID: #{whatsapp_channel.id}"
  
          begin
            # Fíjate en la sintaxis con `whatsapp_channel:` 
            Whatsapp::Providers::WhatsappCloudService
              .new(whatsapp_channel: whatsapp_channel)
              .sync_templates
  
          rescue StandardError => e
            Rails.logger.error "🚨 Error sincronizando Channel ID: #{whatsapp_channel.id}. Detalle: #{e.message}"
            errors << { channel_id: whatsapp_channel.id, error: e.message }
          end
        end
  
        if errors.empty?
          render json: { message: 'All WhatsApp templates synchronized successfully' }, status: :ok
        else
          Rails.logger.warn "⚠️ Algunos canales fallaron en la sincronización: #{errors}"
          render json: { message: 'Some WhatsApp templates failed to synchronize', errors: errors }, status: :partial_content
        end
      else
        render json: { error: 'No WhatsApp channels found for this account' }, status: :not_found
      end
    end
  
    private
  
    def set_account
      @account = Account.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Account not found' }, status: :not_found
    end
  end