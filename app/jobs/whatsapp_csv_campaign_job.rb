class WhatsappCsvCampaignJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_campaigns, retry: 3

  def perform(campaign_id)
    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    campaign.update!(campaign_status: :processing)

    Whatsapp::CsvCampaignService.new(campaign).perform

    campaign.update!(campaign_status: :completed)
  rescue StandardError => e
    campaign&.update!(campaign_status: :failed)
    raise e
  end
end
