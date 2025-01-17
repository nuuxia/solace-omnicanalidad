module Whatsapp
  class SendTemplateService
    attr_reader :phone_number_id, :version, :to, :template, :token

    def initialize(phone_number_id:, version:, to:, template:, token: nil)
      @phone_number_id = phone_number_id
      @version = version || 'v20.0'
      @to = to
      @template = template
      @token = token

    end

    def perform
      raise "Missing phone_number_id" unless phone_number_id.present?

      uri = URI("https://graph.facebook.com/#{version}/#{phone_number_id}/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = build_payload.to_json

      log_request_details(uri, request.body)

      response = http.request(request)
      log_response_details(response)

      raise "Error in WhatsApp API: #{response.body}" unless response.code.to_i == 200

      JSON.parse(response.body)
    rescue StandardError => e
      log_error_details(e)
      raise "Error sending WhatsApp message: #{e.message}"
    end

    private

    def build_payload
      {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: to,
        type: 'template',
        template: {
          name: template['name'],
          language: {
            code: template['language']
          }
        }
      }
    end

    def log_request_details(uri, payload)
      Rails.logger.info "\n===== WhatsApp API Request ====="
      Rails.logger.info "URI: #{uri}"
      Rails.logger.info "Payload: #{payload}"
      Rails.logger.info "===============================\n"
    end

    def log_response_details(response)
      Rails.logger.info "\n===== WhatsApp API Response ====="
      Rails.logger.info "Status Code: #{response.code}"
      Rails.logger.info "Body: #{response.body}"
      Rails.logger.info "===============================\n"
    end

    def log_error_details(error)
      Rails.logger.info "\n===== WhatsApp API Error ====="
      Rails.logger.info "Error Message: #{error.message}"
      Rails.logger.info "Backtrace: #{error.backtrace.join("\n")}"
      Rails.logger.info "=============================\n"
    end
  end
end
