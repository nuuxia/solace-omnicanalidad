# frozen_string_literal: true

require 'csv'

module Whatsapp
  class CampaignCsvWhatsappService # <─ 👈  constante = Whatsapp::CampaignCsvWhatsappService
    HEADER = %w[phone_number status error].freeze

    def initialize(campaign)
      @campaign = campaign

      source = if campaign.processed_csv.attached?
                 campaign.processed_csv
               else
                 campaign.original_csv
               end

      @csv_path = Rails.root.join('tmp', "campaign_#{campaign.id}.csv")
      File.binwrite(@csv_path, source.download)
      @rows = CSV.table(@csv_path, headers: true)
    end

    #
    # Llamado por WhatsappCsvCampaignJob
    #
    def perform
      raise 'campaign not in processing' unless @campaign.processing?

      @rows.each_with_index do |row, idx|
        next if row[:status] == 'sent' # ya enviado en pasadas anteriores

        WhatsappCsvMessageJob.perform_async(@campaign.id, idx)
      end
    end

    #
    # Usado por WhatsappCsvMessageJob para una sola fila
    #
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
        row[:error]  = resp.inspect.truncate(120)
        @campaign.increment!(:messages_failed)
      end
    rescue StandardError => e
      row[:status] = 'failed'
      row[:error]  = e.message.truncate(120)
      @campaign.increment!(:messages_failed)
      Rails.logger.error "[CsvCampaignService] Error row #{phone}: #{e.message}"
    end

    #
    # Sube el CSV actualizado a S3 / ActiveStorage
    #
    def flush_csv!
      tmp = Tempfile.new(['processed', '.csv'])
      CSV.open(tmp.path, 'w') do |csv|
        csv << @rows.headers
        @rows.each { |r| csv << r }
      end

      @campaign.processed_csv.purge if @campaign.processed_csv.attached?
      @campaign.processed_csv.attach(
        io: tmp,
        filename: "processed_#{@campaign.id}_#{Time.current.to_i}.csv",
        content_type: 'text/csv'
      )
      @campaign.update!(processed_csv_filename: tmp.path.split('/').last)
      tmp.close!
    end

    private

    def download_csv
      dest = Rails.root.join('tmp', "campaign_#{@campaign.id}.csv")
      File.binwrite(dest, @campaign.original_csv.download)
      dest
    end
  end
end
