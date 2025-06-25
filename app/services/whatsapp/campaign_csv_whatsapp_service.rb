# app/services/whatsapp/campaign_csv_whatsapp_service.rb
# frozen_string_literal: true

require 'csv'
require 'open-uri'

module Whatsapp
  class CampaignCsvWhatsappService
    attr_reader :campaign, :rows

    def initialize(campaign)
      @campaign = campaign
      @rows     = parse_csv
      Rails.logger.info "📑 Loaded #{@rows.size} CSV rows for campaign #{campaign.id}"
    end

    # ------------------------------------------------------------------
    # Enviar el template expandido a una fila
    # ------------------------------------------------------------------
    def send_row(row, expanded_template)
      Whatsapp::SendTemplateService.new(
        phone_number_id: campaign.inbox.phone_number_id,
        version: ENV.fetch('VITE_FB_GRAPH_API_VERSION', 'v19.0'),
        to: row[:phone_number],
        template: expanded_template,
        token: campaign.inbox.whatsapp_api_key
      ).perform
    end

    # Stub para re-subir un CSV de progreso
    def flush_csv!
      # Implementa aquí si quieres volver a subir el CSV procesado.
    end

    # ------------------------------------------------------------------
    private

    # ------------------------------------------------------------------

    def parse_csv
      io =
        if campaign.csv_original_url.present?
          URI.open(campaign.csv_original_url)                     # remoto
        elsif campaign.original_csv.attached?
          StringIO.new(campaign.original_csv.download)            # ActiveStorage
        else
          raise 'CSV source missing (csv_original_url or original_csv)'
        end

      # ‼️ Leemos el *contenido* y lo parseamos:
      CSV.parse(io.read,
                headers: true,
                header_converters: :symbol).map(&:to_h)
    ensure
      io&.close
    end
  end
end
