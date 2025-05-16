class WhatsappCampaignJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_campaigns, retry: 3

  def perform(campaign_id)
    Rails.logger.info "[WhatsappCampaignJob] Iniciando campaña con ID=#{campaign_id}"
    campaign = CampaignsWhatsapp.find(campaign_id)
    Rails.logger.info "[WhatsappCampaignJob] Campaña encontrada: #{campaign.title}"
    
    campaign.update!(campaign_status: :processing)
    Rails.logger.info "[WhatsappCampaignJob] Campaña actualizada a 'processing'"
    
    Rails.logger.info "[WhatsappCampaignJob] Inicializando CampaignService..."
    perform_campaign(campaign)
    Rails.logger.info "[WhatsappCampaignJob] Campaña #{campaign_id} completada exitosamente"
  rescue StandardError => e
    Rails.logger.error "[WhatsappCampaignJob] La campaña #{campaign_id} falló: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    campaign&.update!(campaign_status: :failed)
    raise e
  end

  private

  def perform_campaign(campaign)
     service = Whatsapp::CampaignWhatsappService.new(campaign) 
    service.perform
  end
end