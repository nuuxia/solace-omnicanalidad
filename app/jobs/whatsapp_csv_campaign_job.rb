# app/workers/whatsapp_csv_campaign_job.rb
# frozen_string_literal: true

class WhatsappCsvCampaignJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_campaigns, retry: 3

  # ------------------------------------------------------------------
  # Encola un WhatsappCsvMessageJob por cada fila *pendiente*
  # (status nulo, vacío o distinto de 'sent').
  # ------------------------------------------------------------------
  def perform(campaign_id)
    Rails.logger.info "[CsvCampaignJob] Starting campaign #{campaign_id}"

    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    service  = Whatsapp::CampaignCsvWhatsappService.new(campaign)

    # ----------------------------------------------------------------
    # Filtrar sólo las filas que todavía no se enviaron
    # ----------------------------------------------------------------
    pending_indices = []
    service.rows.each_with_index do |row, idx|
      status = row[:status].to_s.downcase
      pending_indices << idx unless status == 'sent'
    end

    total_pending = pending_indices.size
    Rails.logger.info "[CsvCampaignJob] #{total_pending} rows pending"

    # Nada para hacer → marcamos de inmediato como completada
    if total_pending.zero?
      campaign.update!(campaign_status: :completed)
      Rails.logger.info "[CsvCampaignJob] Campaign #{campaign_id} already completed"
      return
    end

    # Guardamos cuántos mensajes *pendientes* quedan por procesar.
    # messages_sent/messages_failed NO se tocan aquí (los va llevando
    # WhatsappCsvMessageJob).
    campaign.update!(messages_total: total_pending, campaign_status: :processing)

    # Encolamos sólo los índices pendientes
    pending_indices.each do |idx|
      WhatsappCsvMessageJob.perform_async(campaign.id, idx)
    end

    Rails.logger.info "📤 Enqueued #{total_pending} WhatsappCsvMessageJob jobs"
  rescue StandardError => e
    campaign&.update!(campaign_status: :failed)
    Rails.logger.error "❌ CsvCampaignJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
