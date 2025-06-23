class CampaignsCsvWhatsapp < ApplicationRecord
  self.table_name = 'campaigns_csv_whatsapp'

  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  has_one_attached :csv_file                      # CSV original o “última versión”

  enum campaign_status: { scheduled: 0, processing: 1, completed: 2, failed: 3 }

  validates :title, :template, presence: true

  # wrapper para lanzar el job
  def kickoff!
    WhatsappCsvCampaignJob.perform_async(id)
  end
end
