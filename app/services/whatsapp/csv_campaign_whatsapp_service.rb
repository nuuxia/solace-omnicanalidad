module Whatsapp
  class CsvCampaignService
    RATE   = 10 # msg/seg
    HEADER = %w[phone_number status error]

    def initialize(campaign)
      @campaign = campaign
      @csv_path = download_csv
      @rows     = CSV.table(@csv_path, headers: true)
    end

    def perform
      raise 'campaign not processing' unless @campaign.processing?

      @rows.each_with_index do |row, idx|
        next if row[:status] == 'sent' # ya enviado en corridas previas

        WhatsappCsvMessageJob.perform_async(@campaign.id, idx)
      end
    end

    # usado desde el job de mensajes
    def send_row(row, template_expanded)
      phone = row[:phone_number]
      resp  = Whatsapp::SendTemplateService.new(
        phone_number_id: @campaign.inbox.phone_number_id,
        version: ENV.fetch('VITE_FB_GRAPH_API_VERSION', 'v19.0'),
        to: phone,
        template: template_expanded,
        token: @campaign.inbox.whatsapp_api_key
      ).perform

      if resp.dig('messages', 0, 'message_status') == 'accepted'
        row[:status] = 'sent'
        @campaign.increment!(:messages_sent)
      else
        row[:status] = 'failed'
        row[:error]  = resp.inspect.truncate(90)
        @campaign.increment!(:messages_failed)
      end
    rescue StandardError => e
      row[:status] = 'failed'
      row[:error]  = e.message.truncate(90)
      @campaign.increment!(:messages_failed)
      Rails.logger.error "[CsvCampaignService] Error row #{phone}: #{e.message}"
    end

    def flush_csv!
      tmp = Tempfile.new(['updated', '.csv'])
      CSV.open(tmp.path, 'w') do |csv|
        csv << @rows.headers
        @rows.each { |r| csv << r }
      end
      @campaign.csv_file.attach(io: tmp, filename: "campaign_#{@campaign.id}_progress.csv", content_type: 'text/csv')
      tmp.close!
    end

    private

    def download_csv
      dest = Rails.root.join('tmp', "campaign_#{@campaign.id}.csv")
      File.binwrite(dest, @campaign.csv_file.download)
      dest
    end
  end
end
