# frozen_string_literal: true

class WhatsappCsvCampaignJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_campaigns, retry: 3

  def perform(campaign_id)
    Rails.logger.info "[CsvCampaignJob] Starting campaign #{campaign_id}"
    campaign = CampaignsCsvWhatsapp.find(campaign_id)

    service = Whatsapp::CampaignCsvWhatsappService.new(campaign)
    total   = service.rows.size

    campaign.update!(messages_total: total, campaign_status: :processing)
    Rails.logger.info "[CsvCampaignJob] #{total} rows to process"

    service.rows.each_index do |idx|
      WhatsappCsvMessageJob.perform_async(campaign.id, idx)
    end
    Rails.logger.info "📤 Enqueued #{total} WhatsappCsvMessageJob jobs"
  rescue StandardError => e
    campaign&.update!(campaign_status: :failed)
    Rails.logger.error "❌ CsvCampaignJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
