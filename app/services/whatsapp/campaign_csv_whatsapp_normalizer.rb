# frozen_string_literal: true

require 'csv'

module Whatsapp
  class CampaignCsvWhatsappNormalizer
    REQUIRED_COLS = %w[phone_number status].freeze

    def initialize(io, country_code: '')
      @io_in  = io
      @io_out = StringIO.new
      @country_code = country_code
    end

    # devuelve un StringIO listo para attach
    def perform
      rows = CSV.read(@io_in, headers: true, encoding: 'utf-8')

      headers_map = rows.headers.index_with do |h|
        h.to_s.strip.downcase.tr(' ', '_')
      end
      missing = REQUIRED_COLS - headers_map.values
      raise StandardError, "missing columns #{missing.join(', ')}" if missing.any?

      CSV(@io_out, write_headers: true, headers: headers_map.values) do |csv|
        rows.each { |row| csv << normalize_row(row, headers_map) }
      end

      @io_out.rewind
      @io_out
    end

    private

    def normalize_row(row, headers_map)
      headers_map.each_with_object({}) do |(orig, norm), h|
        value = row[orig]

        case norm
        when 'phone_number'
          value = value.to_s.gsub(/\D/, '')
          value = "+#{@country_code}#{value}" unless value.start_with?('+')
        when 'email'
          value = value.to_s.downcase
        end

        h[norm] = value
      end
    end
  end
end
