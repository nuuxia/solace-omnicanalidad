# frozen_string_literal: true

# app/services/whatsapp/campaign_csv_whatsapp_file_upload_service.rb

require 'aws-sdk-s3'

module Whatsapp
  # Sube el CSV de la campaña a S3 y devuelve una URL pre-firmada
  # para que el front-end pueda descargarlo en cualquier momento.
  #
  # Si quieres que la URL dure más o menos tiempo, cambia
  # DEFAULT_EXPIRATION o pasa `expires_in:` en initialize.
  class CampaignCsvWhatsappFileUploadService
    DEFAULT_EXPIRATION = 7.days.to_i # 604 800 s

    def initialize(file, expires_in: DEFAULT_EXPIRATION)
      @file       = file
      @expires_in = expires_in
    end

    # @return [String, nil] URL pre-firmada o nil si no hay archivo
    def perform
      return nil unless @file

      validate_csv! # ← lanza ArgumentError si no es CSV

      Rails.logger.info do
        "📤 S3 upload => bucket=#{bucket_name}, region=#{aws_region}, key=#{object_key}"
      end

      obj = s3_resource
            .bucket(bucket_name)
            .object(object_key)

      # Sube el archivo: pasamos el IO para imitar tu servicio anterior ▶
      obj.upload_file(@file.tempfile, content_type: @file.content_type)

      # Genera la URL pre-firmada
      obj.presigned_url(
        :get,
        expires_in: @expires_in,
        response_content_disposition:
          %(attachment; filename="#{sanitized_filename}")
      )
    end

    private

    # ------------------------------------------------------------------
    # Validaciones simples
    # ------------------------------------------------------------------
    def validate_csv!
      return if csv_file?

      raise ArgumentError,
            'Expected a CSV file, got ' \
            "#{@file.content_type || @file.original_filename}"
    end

    def csv_file?
      mime_ok = @file.content_type.to_s == 'text/csv'
      ext_ok  = File.extname(@file.original_filename).casecmp('.csv').zero?
      mime_ok || ext_ok
    end

    # ------------------------------------------------------------------
    # AWS helpers
    # ------------------------------------------------------------------
    def aws_region
      ENV.fetch('AWS_REGION')
    end

    def bucket_name
      ENV.fetch('S3_BUCKET_NAME')
    end

    # Un único Aws::S3::Resource por llamada
    def s3_resource
      @s3_resource ||= Aws::S3::Resource.new(
        region: aws_region,
        credentials: Aws::Credentials.new(
          ENV.fetch('AWS_ACCESS_KEY_ID'),
          ENV.fetch('AWS_SECRET_ACCESS_KEY')
        )
      )
    end

    # campaigns_csv_whatsapp/<UUID>/<archivo_sanitizado>
    def object_key
      @object_key ||= File.join(
        'campaigns_csv_whatsapp',
        SecureRandom.uuid,
        sanitized_filename
      )
    end

    # Reemplazamos caracteres problemáticos para S3
    def sanitized_filename
      @sanitized_filename ||= begin
        base = File.basename(@file.original_filename.presence || 'file.csv')
        base.gsub(/[^\w.-]/, '_')
      end
    end
  end
end
