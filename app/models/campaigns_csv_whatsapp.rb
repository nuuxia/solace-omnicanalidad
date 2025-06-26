# frozen_string_literal: true

class CampaignsCsvWhatsapp < ApplicationRecord
  self.table_name = 'campaigns_csv_whatsapp'

  # ─────────── Associations ───────────
  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  # (bórralas si dejaste de usar ActiveStorage)
  has_one_attached :original_csv
  has_one_attached :processed_csv

  # ─────────── Enums ───────────
  enum campaign_status: { scheduled: 0, processing: 1, completed: 2, failed: 3 }

  # ─────────── Validations ───────────
  validates :title,    presence: true
  validates :template, presence: true
  validate  :csv_source_presence

  # ─────────── Callbacks ───────────
  after_commit :kickoff_async, on: :create

  # ─────────── Public helpers ───────────
  #
  def progress_data
    {
      total: messages_total,
      sent: messages_sent,
      failed: messages_failed,
      pending: messages_total - messages_sent - messages_failed,
      percent_complete: messages_total.zero? ? 0 : ((messages_sent + messages_failed) * 100.0 / messages_total).round(1)
    }
  end

  def processed?
    csv_sent_url.present? || csv_errors_url.present? || processed_csv.attached?
  end

  private

  def csv_source_presence
    return if csv_original_url.present?
    return if original_csv.attached?

    errors.add(:base, I18n.t('errors.csv_missing'))
  end

  # Encola sólo si NO es futura
  def kickoff_async
    return if scheduled_at.present? && scheduled_at.future?

    WhatsappCsvCampaignJob.perform_async(id)
  end
end
