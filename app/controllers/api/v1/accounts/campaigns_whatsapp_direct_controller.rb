# app/controllers/api/v1/accounts/campaigns_whatsapp_direct_controller.rb
module Api
  module V1
    module Accounts
      class CampaignsWhatsappDirectController < ApplicationController
        before_action :set_account
        before_action :set_campaign, only: [:update, :destroy]

        # POST /api/v1/accounts/:account_id/campaigns_whatsapp/direct
        def create
          @campaign = @account.campaigns_whatsapp.new(campaign_params)
          if @campaign.save
            render json: @campaign, status: :created
          else
            render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/accounts/:account_id/campaigns_whatsapp/:id/direct
        def update
          if @campaign.update(campaign_params)
            render json: @campaign, status: :ok
          else
            render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/accounts/:account_id/campaigns_whatsapp/:id/direct
        def destroy
          @campaign.destroy
          head :no_content
        end

        private

        def set_account
          @account = Account.find(params[:account_id])
        end

        def set_campaign
          @campaign = @account.campaigns_whatsapp.find(params[:id])
        end

        def campaign_params
          params.require(:campaigns_whatsapp).permit(:name, :template, :campaign_type, :scheduled_at)
        end
      end
    end
  end
end