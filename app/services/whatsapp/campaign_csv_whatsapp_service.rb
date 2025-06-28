# frozen_string_literal: true

require 'csv'
require 'open-uri'
require 'tempfile'

module Whatsapp
  class CampaignCsvWhatsappService
    attr_reader :campaign, :csv_path

    STATUS_HEADERS = %i[status error].freeze
    RES_KEY_PREFIX = 'csv_row_status'

    # --------------------------------------------------------------
    def initialize(campaign)
      @campaign = campaign
      @csv_path = download_csv # tmp/…csv
    end

    # --------------------------------------------------------------
    # Devuelve un array de hashes con los datos necesarios + índice
    # y omite las filas cuyo status ya es 'sent'; de esta forma, al
    # reenviar una campaña reutilizando el CSV procesado, sólo
    # reintentas las que fallaron / las nuevas.
    # --------------------------------------------------------------
    def pending_rows
      out = []
      CSV.foreach(csv_path, headers: true).with_index do |row, idx|
        next if row['status'].to_s.downcase == 'sent'

        out << {
          idx: idx,
          phone_number: row['phone_number'],
          first_name: row['first_name'],
          last_name: row['last_name'],
          email: row['email']
        }
      end
      out
    end

    # --------------------------------------------------------------
    # Genera el CSV final mezclando el original + los resultados
    # salvados en Redis por los workers, **manteniendo la fila de
    # encabezados** y añadiendo columnas status/error si no existen.
    # --------------------------------------------------------------
    def flush_csv!
      redis_key = "#{RES_KEY_PREFIX}:#{campaign.id}"
      results   = Sidekiq.redis { |r| r.hgetall(redis_key) }
                         .transform_values { |v| JSON.parse(v) }

      tmp = Tempfile.new(["processed_#{campaign.id}_", '.csv'])

      # Leemos el CSV original con headers
      orig = CSV.read(csv_path, headers: true)

      # 1️⃣ Encabezados originales + columnas extra
      headers = orig.headers.map(&:to_s)
      STATUS_HEADERS.each { |h| headers << h.to_s unless headers.include?(h.to_s) }

      CSV.open(tmp.path, 'w') do |csv|
        csv << headers # ← fila de encabezados

        orig.each_with_index do |row, idx|
          row_hash = row.to_hash

          if (res = results[idx.to_s])
            row_hash['status'] = res['status']
            row_hash['error']  = res['error']
          end

          csv << headers.map { |h| row_hash[h] }
        end
      end

      attach_to_campaign!(tmp) # ActiveStorage / S3
      tmp.path
    ensure
      tmp&.close
    end

    # --------------------------------------------------------------
    private

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
