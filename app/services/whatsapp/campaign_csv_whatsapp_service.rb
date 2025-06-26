# app/services/whatsapp/campaign_csv_whatsapp_service.rb
# frozen_string_literal: true

require 'csv'
require 'open-uri'

module Whatsapp
  # Servicio responsable de:
  #   • Bajar el CSV de la campaña (original o previamente procesado)
  #   • Mantenerlo en memoria como CSV::Table para poder editar filas
  #   • Volcar los cambios en un nuevo CSV y exponer la ruta para que
  #     el *job* lo suba a S3 (o Active-Storage)
  class CampaignCsvWhatsappService
    attr_reader :campaign, :rows, :processed_path

    # ------------------------------------------------------------------
    # INIT
    # ------------------------------------------------------------------
    def initialize(campaign)
      @campaign = campaign
      @csv_path = download_csv                        # tmp/…csv
      @rows     = CSV.table(@csv_path, headers: true) # ⇒ CSV::Table
      ensure_status_columns!
      Rails.logger.info "📑 Loaded #{@rows.size} CSV rows for campaign #{campaign.id}"
    end

    # ------------------------------------------------------------------
    # Enviar el template expandido a una fila (wrapper)
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

    # ------------------------------------------------------------------
    # Volcar el CSV actualizado a disco para que el worker lo suba
    # – Devuelve la ruta del archivo generado.
    # ------------------------------------------------------------------
    def flush_csv!
      tmp = Tempfile.new(["processed_#{campaign.id}_", '.csv'])
      CSV.open(tmp.path, 'w') do |csv|
        csv << rows.headers
        rows.each { |r| csv << r }
      end

      @processed_path = tmp.path # ← queda disponible para el job
      attach_to_campaign!(tmp)
      tmp.path
    ensure
      tmp&.close
    end

    # ------------------------------------------------------------------
    private

    # ------------------------------------------------------------------

    # Baja el CSV original/procesado a un archivo temporal y
    # devuelve la ruta absoluta.
    def download_csv
      io =
        if campaign.processed_csv.attached?
          StringIO.new(campaign.processed_csv.download)
        elsif campaign.original_csv.attached?
          StringIO.new(campaign.original_csv.download)
        elsif campaign.csv_original_url.present?
          URI.open(campaign.csv_original_url)
        else
          raise 'CSV source missing (csv_original_url or original_csv)'
        end

      dest = Rails.root.join('tmp', "campaign_#{campaign.id}.csv")
      File.binwrite(dest, io.read)
      dest
    ensure
      io&.close
    end

    def ensure_status_columns!
      %i[status error].each do |col|
        next if @rows.headers.include?(col)

        @rows.each { |r| r[col] = nil }
        @rows.headers << col
      end
    end

    # Adjunta el nuevo CSV procesado a la campaña (ActiveStorage)
    # y guarda el nombre para mostrárselo al usuario.
    def attach_to_campaign!(io)
      campaign.processed_csv.purge if campaign.processed_csv.attached?

      campaign.processed_csv.attach(
        io: io,
        filename: File.basename(io.path),
        content_type: 'text/csv'
      )

      campaign.update!(processed_csv_filename: File.basename(io.path))
    end
  end
end
