module Whatsapp
    class CampaignWhatsappService
      attr_reader :campaign
  
      def initialize(campaign)
        @campaign = campaign
        Rails.logger.info "🔄 Initialized CampaignWhatsappService for campaign #{campaign.id}"
      end
  
      def perform
        Rails.logger.info "🚀 Starting CampaignWhatsappService for campaign #{campaign.id}"
        validate_campaign
        Rails.logger.info "✅ Campaign validation passed"
  
        campaign.update!(campaign_status: :processing)
        Rails.logger.info "⚙️ Updated campaign status to processing"
  
        Rails.logger.info "👥 Getting audience labels..."
        labels = get_audience_labels
        Rails.logger.info "📋 Found labels: #{labels.join(', ')}"
  
        process_audience(labels)
  
        campaign.update!(campaign_status: :completed)
        Rails.logger.info "✅ Campaign #{campaign.id} completed successfully"
      rescue StandardError => e
        campaign.update!(campaign_status: :failed)
        Rails.logger.error "❌ Campaign #{campaign.id} failed: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        raise e
      end
  
      private
  
      def validate_campaign
        Rails.logger.info "🔍 Validating campaign..."
        raise "Invalid Campaign Type" unless campaign.inbox.whatsapp?
        raise "Campaign has no template" if campaign.template.blank?
        raise "Campaign has no audience" if campaign.audience.blank?
        Rails.logger.info "✅ Campaign validated successfully for ID=#{campaign.id}"
      end
  
      def get_audience_labels
        Rails.logger.info "🏷️ Processing audience for campaign #{campaign.id}..."
  
        audience_label_ids = campaign.audience
                                    .select { |aud| aud['type'] == 'Label' }
                                    .map    { |aud| aud['id'] }
  
        Rails.logger.info "🏷️ Found label IDs: #{audience_label_ids.join(', ')}"
  
        labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)
        Rails.logger.info "📋 Retrieved label titles: #{labels.join(', ')}"
  
        raise "No valid labels found in audience" if labels.empty?
  
        labels
      end
  
      def process_audience(audience_labels)
        Rails.logger.info "👥 Finding contacts with labels: #{audience_labels.join(', ')}"
  
        contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
        total_contacts = contacts.count
  
        Rails.logger.info "📊 Found #{total_contacts} total contacts to process"
        campaign.update!(messages_total: total_contacts)
  
        if total_contacts.zero?
          Rails.logger.warn "⚠️ No contacts found for the given labels"
          return
        end
  
        process_contacts_in_batches(contacts, total_contacts)
      end
  
      def process_contacts_in_batches(contacts, total_contacts)
        Rails.logger.info "🔄 Starting batch processing of contacts..."
  
        contacts.find_each.with_index do |contact, index|
          if contact.phone_number.blank?
            Rails.logger.warn "⚠️ Skipping contact #{contact.id} - no phone number"
            next
          end
  
          Rails.logger.info "📤 Queueing message #{index + 1}/#{total_contacts} "\
                           "for contact #{contact.id} (#{contact.phone_number})"
  
          begin
            WhatsappMessageJob.perform_async(campaign.id, contact.id)
            Rails.logger.info "✅ Successfully queued message for contact #{contact.id}"
          rescue StandardError => e
            Rails.logger.error "❌ Failed to queue message for contact #{contact.id}: #{e.message}"
            # Continúa con los demás aunque falle uno
          end
        end
  
        Rails.logger.info "✅ Completed queueing messages for all contacts"
      end
    end
  end