# frozen_string_literal: true

require 'ostruct'

class WhatsappCsvMessageJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_messages, retry: 3

  MESSAGES_PER_SECOND = 10
  RATE_KEY_PREFIX     = 'whatsapp_csv_rate'

  def perform(campaign_id, row_index)
    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    service  = Whatsapp::CampaignCsvWhatsappService.new(campaign)

    row = service.rows[row_index] or raise "Row #{row_index} not found"

    template_hash      = safe_hash(campaign.template)
    body_vars_parsed   = safe_array(campaign.body_variables)
    button_vars_parsed = safe_array(campaign.button_variables)

    expanded_template = Whatsapp::TemplatePlaceholderService.new(
      template: template_hash.deep_dup,
      body_variables: body_vars_parsed,
      button_variables: button_vars_parsed,
      contact: fake_contact(row),
      header_media_url: template_hash['header_media_url'],
      row: row # ← 🔹 nuevo parámetro
    ).perform

    enforce_rate_limit

    service.send_row(row, expanded_template)
    update_counters(campaign)

    # Persist each 25 rows or the last row
    service.flush_csv! if (row_index % 25).zero? || row_index == service.rows.size - 1
  rescue StandardError => e
    Rails.logger.error "❌ WhatsappCsvMessageJob error (campaign=#{campaign_id}, row=#{row_index}): #{e.message}"
    campaign.increment!(:messages_failed) if campaign&.persisted?
    raise e
  end

  # -------------------------- helpers ↓ ---------------------------------------

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

  # ---------- rate-limit & counters ------------------------------------------

  def enforce_rate_limit
    key   = "#{RATE_KEY_PREFIX}:#{Time.now.to_i}"
    count = Sidekiq.redis { |r| r.incr(key) }
    Sidekiq.redis { |r| r.expire(key, 2) } if count == 1
    sleep 1 if count > MESSAGES_PER_SECOND
  end

  def update_counters(campaign)
    campaign.increment!(:messages_sent)
    maybe_finish_campaign(campaign)
  end

  def maybe_finish_campaign(campaign)
    done = campaign.messages_sent + campaign.messages_failed
    return unless done >= campaign.messages_total

    status = campaign.messages_failed.positive? ? :failed : :completed
    campaign.update!(campaign_status: status)
  end
end
