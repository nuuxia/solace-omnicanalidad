module Whatsapp
  class CampaignPreviewService
    attr_reader :inbox, :template, :phone_number

    def initialize(inbox:, template:, phone_number:)
      @inbox = inbox
      @template = template
      @phone_number = phone_number
      Rails.logger.info "📱 Initializing preview for template #{template['name']} to #{phone_number}"
    end

    def perform
      validate_params
      send_preview_message
    end

    private

    def validate_params
      raise 'Invalid inbox type' unless inbox.whatsapp?
      raise 'Invalid phone number' unless phone_number.match?(/^\+[0-9]+$/)
      raise 'Template is required' if template.blank?
    end

    def send_preview_message
      Whatsapp::SendTemplateService.new(
        phone_number_id: inbox.phone_number_id,
        version: ENV['VITE_FB_GRAPH_API_VERSION'],
        to: phone_number,
        template: template,
        token: inbox.whatsapp_api_key
      ).perform
    end
    
  end
end