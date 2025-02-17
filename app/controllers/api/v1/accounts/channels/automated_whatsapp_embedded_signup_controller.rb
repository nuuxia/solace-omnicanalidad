class Api::V1::Accounts::Channels::AutomatedWhatsappEmbeddedSignupController < Api::V1::Accounts::BaseController
    before_action :authorize_request
  
    def create
      payload = params.require(:automated_whatsapp_embedded_signup).permit(:waba_id, :phone_number_id)
  
      unless payload[:waba_id].present? && payload[:phone_number_id].present?
        render json: { error: 'Both waba_id and phone_number_id are required' }, status: :unprocessable_entity
        return
      end
  
      
  
      result = Whatsapp::Providers::AutomatedWhatsappCloudService.new(
        account_id: params[:account_id],
        waba_id: payload[:waba_id],
        phone_number_id: payload[:phone_number_id]
      ).call
  
      if result&.key?(:inbox_id)
        render json: {
          message: 'WhatsApp Embedded Signup process completed successfully',
          inbox_id: result[:inbox_id],
          waba_id: result[:waba_id],
          phone_number_id: result[:phone_number_id]
        }, status: :ok
      else
        render json: { error: 'Failed to complete WhatsApp signup process' }, status: :unprocessable_entity
      end
    rescue Pundit::NotAuthorizedError
      render json: { error: 'You are not authorized to perform this action' }, status: :forbidden
    rescue ActionController::ParameterMissing => e
      render json: { error: "Missing or malformed parameters: #{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  
    private
  
    def authorize_request
      authorize ::Inbox
    end
  end