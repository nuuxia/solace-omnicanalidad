# frozen_string_literal: true

# == Schema Information
#
# Table name: campaigns_csv_whatsapp
#
#  id               :bigint           not null, primary key
#  body_variables   :jsonb
#  button_variables :jsonb
#  campaign_status  :integer          default("scheduled")
#  messages_failed  :integer          default(0), not null
#  messages_sent    :integer          default(0), not null
#  messages_total   :integer          default(0), not null
#  scheduled_at     :datetime
#  template         :jsonb
#  title            :string           not null
#  csv_original_url :string
#  csv_sent_url     :string
#  csv_errors_url   :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  inbox_id         :bigint           not null
#  sender_id        :integer
#
# Indexes -- añadí los que necesites
#
class CampaignsCsvWhatsapp < ApplicationRecord
  self.table_name = 'campaigns_csv_whatsapp'

  # ─────────── Associations ───────────
  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  # Active-Storage para CSVs (borralo si lo migraste a S3 directo)
  has_one_attached :original_csv
  has_one_attached :processed_csv

  # ─────────── Enums ───────────
  enum campaign_status: { scheduled: 0, processing: 1, completed: 2, failed: 3 }

  # ─────────── Validations ───────────
  validates :title, :template, :inbox_id, presence: true
  validate  :csv_source_presence

  # ─────────── Callbacks ───────────
  after_commit :kickoff_async, on: :create

  # ─────────── Serialización JSON ───────────
  # Devuelve scheduled_at/created_at como UNIX timestamp
  def as_json(options = {})
    super(options).merge(
      'scheduled_at' => scheduled_at&.to_i,
      'created_at' => created_at.to_i
    )
  end

  # ─────────── Helpers de progreso ───────────
  def progress_data
    {
      total: messages_total,
      sent: messages_sent,
      failed: messages_failed,
      pending: messages_total - messages_sent - messages_failed,
      percent_complete: if messages_total.zero?
                          0
                        else
                          ((messages_sent + messages_failed) * 100.0 / messages_total).round(1)
                        end
    }
  end

  def processed?
    csv_sent_url.present? || csv_errors_url.present? || processed_csv.attached?
  end

  # ─────────── Privado ───────────
  private

  # CSV obligatorio: url o archivo
  def csv_source_presence
    return if csv_original_url.present? || original_csv.attached?

    errors.add(:base, I18n.t('errors.csv_missing'))
  end

  # Lanzar la campaña en Sidekiq si NO está programada
  def kickoff_async
    return if scheduled_at.present? && scheduled_at.future?

    WhatsappCsvCampaignJob.perform_async(id)
  end
end
