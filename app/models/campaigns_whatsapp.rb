# app/models/campaigns_whatsapp.rb
# == Schema Information
#
# Table name: campaigns_whatsapp
#
#  id                                 :bigint           not null, primary key
#  audience                           :jsonb
#  body_variables                     :jsonb
#  button_variables                   :jsonb
#  campaign_status                    :integer          default("scheduled")
#  campaign_type                      :integer          default("ongoing")
#  enabled                            :boolean          default(TRUE)
#  messages_failed                    :integer          default(0), not null
#  messages_sent                      :integer          default(0), not null
#  messages_total                     :integer          default(0), not null
#  scheduled_at                       :datetime
#  template                           :jsonb
#  title                              :string           not null
#  trigger_only_during_business_hours :boolean          default(FALSE)
#  trigger_rules                      :jsonb
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  account_id                         :bigint           not null
#  inbox_id                           :bigint           not null
#  sender_id                          :integer
#
# Indexes
#
#  index_campaigns_whatsapp_on_account_id       (account_id)
#  index_campaigns_whatsapp_on_campaign_status  (campaign_status)
#  index_campaigns_whatsapp_on_campaign_type    (campaign_type)
#  index_campaigns_whatsapp_on_inbox_id         (inbox_id)
#  index_campaigns_whatsapp_on_scheduled_at     (scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class CampaignsWhatsapp < ApplicationRecord
  self.table_name = 'campaigns_whatsapp'

  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  validates :account_id, :inbox_id, :title, :template, presence: true

  # Los estatus y tipos que usas
  enum campaign_status: { scheduled: 0, processing: 1, completed: 2, failed: 3 }
  enum campaign_type: { ongoing: 0, one_off: 1 }

  # body_variables y button_variables se almacenan como JSON (añadidas por la migración)

  def send_messages
    raise "Invalid Campaign" unless inbox&.inbox_type == 'Whatsapp'

    if scheduled_at&.future?
      WhatsappCampaignJob.perform_in(scheduled_at - Time.current, id)
    else
      WhatsappCampaignJob.perform_async(id)
    end
  end

  # Para que scheduled_at sea devuelto como unix timestamp en JSON
  def as_json(options = {})
    super(options).merge(
      'scheduled_at' => scheduled_at&.to_i
    )
  end
end
