class WhatsappCampaignJob
    include Sidekiq::Worker
    sidekiq_options queue: :whatsapp_campaigns, retry: 3
   
    def perform(campaign_id)
      Rails.logger.info "🚀 Starting WhatsappCampaignJob for campaign_id=#{campaign_id}"
      
      campaign = CampaignsWhatsapp.find(campaign_id)
      Rails.logger.info "📋 Found campaign: #{campaign.title}"
      
      campaign.update!(campaign_status: :processing)
      Rails.logger.info "⚙️ Updated campaign status to processing"
      
      Rails.logger.info "🔄 Initializing CampaignService..."
      perform_campaign(campaign)
      Rails.logger.info "✅ Campaign completed successfully"
    rescue StandardError => e
      Rails.logger.error "❌ Campaign #{campaign_id} failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      campaign&.update!(campaign_status: :failed)
      raise e
    end
   
    private
   
    def perform_campaign(campaign)
      service = Whatsapp::CampaignService.new(campaign)
      service.perform
    end
   end