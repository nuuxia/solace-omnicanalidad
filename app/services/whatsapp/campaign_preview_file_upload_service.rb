# app/services/whatsapp/campaign_preview_file_upload_service.rb
# frozen_string_literal: true

module Whatsapp
    class CampaignPreviewFileUploadService
      def initialize(file)
        @file = file
      end
  
      def perform
        return nil unless @file
  
        s3_resource = Aws::S3::Resource.new(
          region: ENV['AWS_REGION'],
          credentials: Aws::Credentials.new(
            ENV['AWS_ACCESS_KEY_ID'],
            ENV['AWS_SECRET_ACCESS_KEY']
          )
        )
        bucket_name = ENV['S3_BUCKET_NAME']
        obj_name = "whatsapp_previews/#{SecureRandom.uuid}/#{@file.original_filename}"
  
        Rails.logger.info "[CampaignPreviewFileUploadService] Subiendo archivo a S3: #{obj_name}"
  
        obj = s3_resource.bucket(bucket_name).object(obj_name)
        obj.upload_file(@file.tempfile, content_type: @file.content_type)
  
        Rails.logger.info "[CampaignPreviewFileUploadService] Archivo subido correctamente a S3"
  
        obj.public_url
      end
    end
  end
  