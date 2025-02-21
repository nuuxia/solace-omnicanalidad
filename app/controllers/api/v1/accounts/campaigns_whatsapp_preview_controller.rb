class Api::V1::Accounts::CampaignsWhatsappPreviewController < Api::V1::Accounts::BaseController
    def create
      result = Whatsapp::CampaignPreviewService.new(
        inbox: inbox,
        template: whatsapp_template_params,
        phone_number: params[:phone_number]
      ).perform
  
      render json: result
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  
    private
  
    def inbox
      @inbox ||= Current.account.inboxes.find(params[:inbox_id])
    end
  
    def whatsapp_template_params
      params.require(:template).permit(:id, :name, :language, :category, components: [])
    end
  end