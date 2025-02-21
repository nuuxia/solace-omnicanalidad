class Api::V1::Accounts::CampaignsWhatsappController < Api::V1::Accounts::BaseController
    before_action :set_campaign, only: [:show, :update, :destroy]
    before_action :check_authorization
    def index
      Rails.logger.info "🔍 [CampaignsWhatsappController#index] Fetching campaigns for account ID=#{Current.account.id}"
      @campaigns = Current.account.campaigns_whatsapp.includes(:inbox)
      Rails.logger.info "📋 Found #{@campaigns.size} campaigns"
      render json: @campaigns.as_json(include: :inbox)
    end
    def show
      Rails.logger.info "👀 [CampaignsWhatsappController#show] Showing campaign ID=#{@campaign.id}"
      render json: @campaign.as_json(include: :inbox)
    end
    def create
      Rails.logger.info "📝 Creating new WhatsApp campaign..."
      @campaign = Current.account.campaigns_whatsapp.new(campaign_params)
      
      if @campaign.save
        Rails.logger.info "✅ Campaign created successfully, ID=#{@campaign.id}"
        schedule_campaign
        render json: @campaign.as_json(include: :inbox), status: :created
      else
        Rails.logger.error "❌ Campaign creation failed: #{@campaign.errors.full_messages}"
        render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
      end
    end
    def update
      Rails.logger.info "📝 [CampaignsWhatsappController#update] Updating campaign ID=#{@campaign.id}"
      
      cleanup_scheduled_jobs if schedule_changed?
      
      if @campaign.update(campaign_params)
        Rails.logger.info "✅ Campaign updated successfully"
        schedule_campaign if schedule_changed?
        render json: @campaign.as_json(include: :inbox)
      else
        Rails.logger.error "❌ Update failed: #{@campaign.errors.full_messages}"
        render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
      end
    end
    def destroy
      Rails.logger.info "🗑️ [CampaignsWhatsappController#destroy] Deleting campaign ID=#{@campaign.id}"
      cleanup_scheduled_jobs
      
      if @campaign.destroy
        Rails.logger.info "✅ Campaign and associated jobs deleted successfully"
        head :ok
      else
        Rails.logger.error "❌ Failed to delete campaign: #{@campaign.errors.full_messages}"
        render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
      end
    end
    private
    def set_campaign
      Rails.logger.info "🔍 [CampaignsWhatsappController#set_campaign] Finding campaign ID=#{params[:id]}"
      @campaign = Current.account.campaigns_whatsapp.find(params[:id])
    end
    def campaign_params
      Rails.logger.info "🔧 Processing campaign parameters"
      permitted = params.require(:campaigns_whatsapp).permit(
        :title,
        :enabled,
        :trigger_only_during_business_hours,
        :inbox_id,
        :sender_id,
        :scheduled_at,
        :campaign_status,
        template: {},
        audience: [:id, :type]
      )
      
      if permitted[:audience].present?
        permitted[:audience] = permitted[:audience].is_a?(Array) ? permitted[:audience] : [permitted[:audience]]
      end
      
      Rails.logger.info "✅ Parameters processed successfully"
      permitted
    end
    def schedule_campaign
      if @campaign.scheduled_at&.future?
        Rails.logger.info "⏰ Scheduling campaign for #{@campaign.scheduled_at}"
        WhatsappCampaignJob.perform_in(@campaign.scheduled_at - Time.current, @campaign.id)
      else
        Rails.logger.info "🚀 Starting campaign immediately"
        WhatsappCampaignJob.perform_async(@campaign.id)
      end
    end
    def cleanup_scheduled_jobs
      return unless @campaign.scheduled_at&.future?
      Rails.logger.info "🧹 Cleaning up scheduled jobs for campaign #{@campaign.id}"
      
      # Clean campaign jobs
      scheduled_set = Sidekiq::ScheduledSet.new
      campaign_jobs = scheduled_set.select do |job| 
        job.klass == 'WhatsappCampaignJob' && job.args.first == @campaign.id
      end
      
      campaign_jobs.each do |job|
        Rails.logger.info "🗑️ Removing scheduled job #{job.jid}"
        job.delete
      end
      # Clean message jobs
      message_jobs = scheduled_set.select do |job|
        job.klass == 'WhatsappMessageJob' && job.args.first == @campaign.id
      end
      message_jobs.each do |job|
        Rails.logger.info "🗑️ Removing scheduled message job #{job.jid}"
        job.delete
      end
      # Clean retry queue
      retry_set = Sidekiq::RetrySet.new
      retry_jobs = retry_set.select do |job|
        (job.klass == 'WhatsappCampaignJob' || job.klass == 'WhatsappMessageJob') && 
        job.args.first == @campaign.id
      end
      retry_jobs.each(&:delete)
      
      Rails.logger.info "✅ Cleaned up #{campaign_jobs.size} campaign jobs, #{message_jobs.size} message jobs, and #{retry_jobs.size} retry jobs"
    end
    def schedule_changed?
      @campaign.scheduled_at_changed? || 
        @campaign.campaign_status_changed? ||
        @campaign.enabled_changed?
    end
  end