# frozen_string_literal: true

class WhatsappCsvCampaignJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_campaigns, retry: 3

  BULK_SIZE = 1_000 # nº de jobs enviados juntos a Sidekiq (ajusta libremente)

  def perform(campaign_id)
    Rails.logger.info "[CsvCampaignJob] Starting campaign #{campaign_id}"

    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    service  = Whatsapp::CampaignCsvWhatsappService.new(campaign)

    rows  = service.pending_rows
    total = rows.size
    raise 'El CSV no tiene filas pendientes' if total.zero?

    Rails.logger.info "[CsvCampaignJob] #{total} filas pendientes"
    campaign.update!(messages_total: total, campaign_status: :processing)

    # ----------------------------------------------------------------
    # Push bulk a Sidekiq en lotes grandes ⇒ súper rápido (< 100 ms)
    # Cada arg es: [campaign_id, idx, phone, fname, lname, email]
    # ----------------------------------------------------------------
    rows.each_slice(BULK_SIZE) do |slice|
      Sidekiq::Client.push_bulk(
        'class' => WhatsappCsvMessageJob,
        'queue' => 'whatsapp_csv_messages',
        'args' => slice.map do |r|
                    [campaign.id, r[:idx], r[:phone_number],
                     r[:first_name], r[:last_name], r[:email]]
                  end
      )
    end

    Rails.logger.info "📤 Enqueued #{total} WhatsappCsvMessageJob"
  rescue StandardError => e
    campaign&.update!(campaign_status: :failed)
    Rails.logger.error "❌ CsvCampaignJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
