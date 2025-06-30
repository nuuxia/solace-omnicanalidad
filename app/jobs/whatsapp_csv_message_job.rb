# app/workers/whatsapp_csv_message_job.rb
# frozen_string_literal: true

require 'ostruct'
require 'json'
require 'csv'

class WhatsappCsvMessageJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_messages, retry: 3

  RATE_LIMIT = ENV.fetch('CAMPAING_CSV_WSP_RATE_LIMIT_MESSAGE_PER_SECOND', 10).to_i
  RATE_KEY   = 'whatsapp_csv_rate'
  DONE_KEY   = 'whatsapp_csv_done'
  RES_KEY    = 'csv_row_status'

  # args: [campaign_id, row_idx, phone, fname, lname, email]
  def perform(campaign_id, row_idx, phone, fname, lname, email)
    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    service  = Whatsapp::CampaignCsvWhatsappService.new(campaign) # sólo para csv_path

    enforce_rate_limit

    # -------- recuperamos la fila completa para las variables -------
    row = CSV.read(service.csv_path, headers: true)[row_idx] ||
          raise("Row #{row_idx} not found")

    contact = OpenStruct.new(
      first_name: fname,
      last_name: lname,
      phone_number: phone,
      email: email
    )

    template_hash = safe_hash(campaign.template)
    expanded      = Whatsapp::TemplatePlaceholderService.new(
      template: template_hash.deep_dup,
      body_variables: safe_array(campaign.body_variables),
      button_variables: safe_array(campaign.button_variables),
      contact: contact,
      header_media_url: template_hash['header_media_url'],
      row: row # ← NUEVO
    ).perform

    status, error_msg = send_and_capture(phone, campaign, expanded)

    # -------- persistimos resultado en Redis ------------------------
    Sidekiq.redis do |r|
      r.hset("#{RES_KEY}:#{campaign_id}", row_idx,
             { status: status, error: error_msg }.to_json)
      processed = r.incr("#{DONE_KEY}:#{campaign_id}")
      finish_campaign_if_done!(campaign, processed)
    end
  rescue StandardError => e
    Rails.logger.error "❌ WhatsappCsvMessageJob (c=#{campaign_id}, row=#{row_idx}): #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  # ------------------------------------------------------------------
  private

  # ------------------------------------------------------------------

  def send_and_capture(phone, campaign, expanded_template)
    Whatsapp::SendTemplateService.new(
      phone_number_id: campaign.inbox.phone_number_id,
      version: ENV.fetch('VITE_FB_GRAPH_API_VERSION', 'v19.0'),
      to: phone,
      template: expanded_template,
      token: campaign.inbox.whatsapp_api_key
    ).perform
    ['sent', ''] # éxito → error vacío
  rescue StandardError => e
    ['error', e.message.tr("\n", ' ')[0, 250]]
  end

  def enforce_rate_limit
    key   = "#{RATE_KEY}:#{Time.now.to_i}"
    count = Sidekiq.redis { |r| r.incr(key) }
    Sidekiq.redis { |r| r.expire(key, 1) } if count == 1
    sleep 1 if count > RATE_LIMIT
  end

  # cierra la campaña cuando se procesaron todas las filas
  def finish_campaign_if_done!(campaign, processed)
    return unless processed >= campaign.messages_total

    csv_service = Whatsapp::CampaignCsvWhatsappService.new(campaign)
    csv_path    = csv_service.flush_csv! # ← mergea resultados

    url = Whatsapp::CampaignCsvWhatsappFileUploadService
          .new(File.open(csv_path)).perform

    results = Sidekiq.redis { |r| r.hvals("#{RES_KEY}:#{campaign.id}") }
                     .map { |j| JSON.parse(j) }

    sent   = results.count { |h| h['status'] == 'sent' }
    failed = results.size - sent

    campaign.update!(
      campaign_status: (failed.positive? ? :failed : :completed),
      messages_sent: sent,
      messages_failed: failed,
      csv_sent_url: url
    )

    # limpieza Redis
    Sidekiq.redis do |r|
      r.del("#{DONE_KEY}:#{campaign.id}")
      r.del("#{RES_KEY}:#{campaign.id}")
    end

    Rails.logger.info "✅ Campaign #{campaign.id} finished (sent=#{sent}, failed=#{failed})"
  end

  # helpers JSON seguros
  def safe_hash(val)
    val.is_a?(String) ? JSON.parse(val) : val || {}
  rescue JSON::ParserError
    {}
  end

  def safe_array(val)
    v = val.is_a?(String) ? JSON.parse(val) : val
    v.is_a?(Array) ? v : []
  rescue JSON::ParserError
    []
  end
end
