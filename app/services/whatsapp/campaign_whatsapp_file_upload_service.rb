require 'aws-sdk-s3'

module Whatsapp
  class CampaignWhatsappFileUploadService
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
      obj_name = "whatsapp_campaings_file/#{SecureRandom.uuid}/#{@file.original_filename}"

      obj = s3_resource.bucket(bucket_name).object(obj_name)

      # Sube el archivo
      options = { content_type: @file.content_type }
      obj.upload_file(@file.tempfile, **options)

      

      # Genera la URL pre-firmada válida por 2 horas y fuerza el filename:
      presigned_url = obj.presigned_url(
        :get,
        expires_in: 7200,
        response_content_disposition: "attachment; filename=\"#{@file.original_filename}\""
      )

    
      presigned_url
    end
  end
end