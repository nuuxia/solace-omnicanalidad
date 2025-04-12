require 'aws-sdk-s3'

module Whatsapp
  class CampaignPreviewFileUploadService
    def initialize(file)
      @file = file
    end

    def perform
      return nil unless @file

      s3_resource = Aws::S3::Resource.new(
        region: ENV['AWS_REGION'],
        credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
      )
      bucket_name = ENV['S3_BUCKET_NAME']
      obj_name = "whatsapp_previews/#{SecureRandom.uuid}/#{@file.original_filename}"

      Rails.logger.info "[CampaignPreviewFileUploadService] Subiendo archivo a S3: #{obj_name}"

      obj = s3_resource.bucket(bucket_name).object(obj_name)

      # No se usa ACL, ya que el bucket tiene enforced Bucket Ownership.
      options = { content_type: @file.content_type }
      obj.upload_file(@file.tempfile, **options)

      Rails.logger.info "[CampaignPreviewFileUploadService] Archivo subido correctamente a S3"

      # Genera una URL pre-firmada válida por 2 horas (7200 segundos)
      presigned_url = obj.presigned_url(:get, expires_in: 7200)
      Rails.logger.info "[CampaignPreviewFileUploadService] URL pre-firmada generada: #{presigned_url}"
      presigned_url
    end
  end
end
