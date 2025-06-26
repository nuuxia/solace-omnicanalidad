# frozen_string_literal: true

require 'ostruct'
require 'json'

class WhatsappCsvMessageJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_messages, retry: 3

  MESSAGES_PER_SECOND = 10
  RATE_KEY_PREFIX     = 'whatsapp_csv_rate'        # rate-limit
  PROCESSED_KEY       = 'whatsapp_csv_processed'   # contador global
  ROW_STATUS_KEY      = 'csv_row_status'           # hash por campaña

  # ------------------------------------------------------------------
  # campaign_id : ID de CampaignsCsvWhatsapp
  # row_index   : índice de la fila en el CSV
  # ------------------------------------------------------------------
  def perform(campaign_id, row_index)
    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    service  = Whatsapp::CampaignCsvWhatsappService.new(campaign)

    row = service.rows[row_index] || raise("Row #{row_index} not found")

    expanded_template = build_expanded_template(campaign, row)

    enforce_rate_limit

    begin
      service.send_row(row, expanded_template)
      mark_row_success!(row_index, campaign)
    rescue StandardError => e
      mark_row_error!(row_index, campaign, e.message)
    ensure
      processed = bump_processed_counter(campaign_id)
      finish_campaign_if_done!(campaign, service, processed)
    end
  rescue StandardError => e
    Rails.logger.error(
      "❌ WhatsappCsvMessageJob error (campaign=#{campaign_id}, row=#{row_index}): #{e.message}"
    )
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  # ------------------------------------------------------------------
  private

  # ------------------------------------------------------------------

  # ---------- template helpers --------------------------------------
  def build_expanded_template(campaign, row)
    template_hash = safe_hash(campaign.template)

    Whatsapp::TemplatePlaceholderService.new(
      template: template_hash.deep_dup,
      body_variables: safe_array(campaign.body_variables),
      button_variables: safe_array(campaign.button_variables),
      contact: fake_contact(row),
      header_media_url: template_hash['header_media_url'],
      row: row
    ).perform
  end

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

  def fake_contact(row)
    OpenStruct.new(
      first_name: row[:first_name],
      last_name: row[:last_name],
      phone_number: row[:phone_number],
      email: row[:email]
    )
  end

  # ---------- rate-limit --------------------------------------------
  def enforce_rate_limit
    key   = "#{RATE_KEY_PREFIX}:#{Time.now.to_i}"
    count = Sidekiq.redis { |r| r.incr(key) }
    Sidekiq.redis { |r| r.expire(key, 2) } if count == 1
    sleep 1 if count > MESSAGES_PER_SECOND
  end

  # ---------- contador global ---------------------------------------
  def bump_processed_counter(campaign_id)
    Sidekiq.redis { |r| r.incr("#{PROCESSED_KEY}:#{campaign_id}") }
  end

  # ---------- cierre de campaña + flush CSV -------------------------
  def finish_campaign_if_done!(campaign, service, processed)
    return unless processed >= campaign.messages_total

    merge_redis_statuses!(campaign.id, service) # ← NUEVO

    # 1) Guardar CSV procesado y generar URL firmada -----------------
    service.flush_csv!
    url = Whatsapp::CampaignCsvWhatsappFileUploadService
          .new(File.open(service.processed_path)).perform

    # 2) Estado final -------------------------------------------------
    final_status = campaign.messages_failed.positive? ? :failed : :completed
    campaign.update!(csv_sent_url: url, campaign_status: final_status)

    # 3) limpiar contadores Redis ------------------------------------
    Sidekiq.redis do |r|
      r.del("#{PROCESSED_KEY}:#{campaign.id}")
      r.del("#{ROW_STATUS_KEY}:#{campaign.id}")
    end

    Rails.logger.info "✅ Campaign #{campaign.id} finished (#{final_status}), CSV uploaded"
  end

  # ---------- escritura en Redis ------------------------------------
  def mark_row_success!(idx, campaign)
    write_row_status_to_redis(campaign.id, idx, 'sent', nil)
    campaign.increment!(:messages_sent)
  end

  def mark_row_error!(idx, campaign, message)
    short = message.to_s.tr("\n", ' ')[0, 250]
    write_row_status_to_redis(campaign.id, idx, 'error', short)
    campaign.increment!(:messages_failed)
  end

  def write_row_status_to_redis(campaign_id, idx, status, error)
    payload = { status: status, error: error }.to_json
    Sidekiq.redis { |r| r.hset("#{ROW_STATUS_KEY}:#{campaign_id}", idx, payload) }
  end

  # ---------- reconstrucción CSV ------------------------------------
  def merge_redis_statuses!(campaign_id, service)
    data = Sidekiq.redis { |r| r.hgetall("#{ROW_STATUS_KEY}:#{campaign_id}") }
    data.each do |idx_str, json|
      values = begin
        JSON.parse(json)
      rescue StandardError
        {}
      end
      row = service.rows[idx_str.to_i]
      next unless row

      row[:status] = values['status']
      row[:error]  = values['error']
    end
  end
end
