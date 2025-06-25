# frozen_string_literal: true

# == Schema Information
#
# table name: campaigns_csv_whatsapp …  (ver schema.rb)
#
class CampaignsCsvWhatsapp < ApplicationRecord
  self.table_name = 'campaigns_csv_whatsapp'

  # ─────────── Associations ───────────
  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  # (mantén las siguientes líneas SOLO si sigues usando ActiveStorage
  #  para estos archivos; de lo contrario elimínalas)
  has_one_attached :original_csv
  has_one_attached :processed_csv

  # ─────────── Enums ───────────
  enum campaign_status: { scheduled: 0, processing: 1, completed: 2, failed: 3 }

  # ─────────── Validations ───────────
  validates :title,    presence: true
  validates :template, presence: true
  validate  :csv_source_presence

  # ─────────── Callbacks ───────────
  #
  # - Si la campaña NO está programada o la fecha ya pasó ⇒ se encola ahora.
  # - Si tiene `scheduled_at` en el futuro ⇒ la encola el controller.
  #
  after_commit :kickoff_async, on: :create

  # ─────────── Helpers ───────────
  def processed?
    csv_sent_url.present? ||
      csv_errors_url.present? ||
      processed_csv.attached?
  end

  private

  # --- Validación de “hay CSV” --------------------------------------------
  def csv_source_presence
    return if csv_original_url.present?
    return if original_csv.attached? # si mantienes ActiveStorage

    errors.add(:base, I18n.t('errors.csv_missing'))
  end

  # --- Encola solo si la fecha es inmediata/pasada ------------------------
  def kickoff_async
    return if scheduled_at.present? && scheduled_at.future?

    WhatsappCsvCampaignJob.perform_async(id)
  end
end
