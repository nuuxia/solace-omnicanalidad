class Api::V1::Accounts::Channels::AutomatedWhatsappEmbeddedSignupController < Api::V1::Accounts::BaseController
  before_action :authorize_request

  def create
    payload = params.require(:automated_whatsapp_embedded_signup)
                    .permit(:waba_id, :phone_number_id, :business_id)

    unless payload[:waba_id].present?
      render json: { error: 'waba_id is required' }, status: :unprocessable_entity
      return
    end

    service =
      if payload[:phone_number_id].present?
        Whatsapp::Providers::AutomatedWhatsappCloudService
      else
        Whatsapp::Providers::AutomatedWhatsappCoexistenceService
      end

    result = service.new(
      account_id: params[:account_id],
      waba_id: payload[:waba_id],
      phone_number_id: payload[:phone_number_id],
      business_id: payload[:business_id]
    ).call

    if result&.key?(:inbox_id)
      render json: result.merge(message: 'WhatsApp onboarding completed'), status: :ok
    else
      render json: { error: 'Failed to complete WhatsApp onboarding' }, status: :unprocessable_entity
    end
  rescue Pundit::NotAuthorizedError
    render json: { error: 'You are not authorized to perform this action' }, status: :forbidden
  end

  private

  def authorize_request
    authorize ::Inbox
  end
end
