# app/services/whatsapp/campaign_csv_whatsapp_file_upload_service.rb
# frozen_string_literal: true

require 'aws-sdk-s3'

module Whatsapp
  class CampaignCsvWhatsappFileUploadService
    DEFAULT_EXPIRATION = 7.days.to_i

    def initialize(file, expires_in: DEFAULT_EXPIRATION)
      @file       = file
      @expires_in = expires_in
    end

    # ------------------------------------------------------------------
    # @return [String, nil] URL pre-firmada o nil si no hay archivo
    # ------------------------------------------------------------------
    def perform
      return nil unless @file

      normalize_file!
      validate_csv!

      Rails.logger.info { "📤 S3 upload => bucket=#{bucket_name}, region=#{aws_region}, key=#{object_key}" }

      obj = s3_resource.bucket(bucket_name).object(object_key)
      obj.upload_file(@io, content_type: @content_type) # 👈 FIX

      obj.presigned_url(
        :get,
        expires_in: @expires_in,
        response_content_disposition: %(attachment; filename="#{sanitized_filename}")
      )
    end

    # ------------------------------------------------------------------
    private

    # ------------------------------------------------------------------

    def normalize_file!
      case @file
      when ActionDispatch::Http::UploadedFile
        @io           = @file.tempfile
        @filename     = @file.original_filename
        @content_type = @file.content_type
      when File, Tempfile
        @io           = @file
        @filename     = File.basename(@file.path)
        @content_type = 'text/csv'
      else
        raise ArgumentError, "Unsupported file class #{@file.class}"
      end
    end

    def validate_csv!
      return if csv_file?

      raise ArgumentError, "Expected a CSV file, got #{@content_type || @filename}"
    end

    def csv_file?
      File.extname(@filename).casecmp('.csv').zero? || @content_type == 'text/csv'
    end

    # ---------- AWS helpers -------------------------------------------
    def aws_region = ENV.fetch('AWS_REGION')
    def bucket_name = ENV.fetch('S3_BUCKET_NAME')

    def s3_resource
      @s3_resource ||= Aws::S3::Resource.new(
        region: aws_region,
        credentials: Aws::Credentials.new(
          ENV.fetch('AWS_ACCESS_KEY_ID'),
          ENV.fetch('AWS_SECRET_ACCESS_KEY')
        )
      )
    end

    def object_key
      @object_key ||= File.join('campaigns_csv_whatsapp', SecureRandom.uuid, sanitized_filename)
    end

    def sanitized_filename                                     # 👈 FIX
      @sanitized_filename ||= @filename.gsub(/[^\w.-]/, '_')
    end
  end
end
