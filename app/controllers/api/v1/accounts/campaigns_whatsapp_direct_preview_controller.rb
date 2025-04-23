# app/controllers/api/v1/accounts/campaigns_whatsapp_direct_preview_controller.rb
module Api
  module V1
    module Accounts
      class CampaignsWhatsappDirectPreviewController < ApplicationController
        before_action :set_account

        # POST /api/v1/accounts/:account_id/campaigns_whatsapp/direct/preview
        def create
          # Aquí debes implementar la lógica de previsualización,
          # por ejemplo invocar un servicio que genere un preview
          preview = PreviewService.new(@account, preview_params).call
          render json: preview, status: :ok
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        private

        def set_account
          @account = Account.find(params[:account_id])
        end

        def preview_params
          params.require(:preview).permit(:template, :recipient_number, :media_url)
        end
      end
    end
  end
end
