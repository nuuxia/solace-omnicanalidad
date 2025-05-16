module MercadoLibre
  class Client
    include HTTParty
    base_uri MERCADO_LIBRE[:base_url]

    def initialize(access_token)
      @access_token = access_token
    end

    def fetch_new_messages(notification)
      Rails.logger.info("[MercadoLibre::Client] Fetching messages for resource=#{notification['resource']}")
      response = self.class.get("/messages/#{notification["resource"]}", headers: headers, query: { tag: 'post_sale' })
      handle_response(response)
    end

    def fetch_question_details(question_id)
      Rails.logger.info("[MercadoLibre::Client] Fetching question #{question_id}")
      response = self.class.get("/questions/#{question_id}", headers: headers)
      handle_response(response)
    end

    def fetch_item_details(item_id)
      response = self.class.get("/items/#{item_id}/permalinks?", headers: headers)
      handle_response(response)
    end

    def fetch_client_data(user_id)
      response = self.class.get("/users/#{user_id}", headers: headers)
      handle_response(response)
    end

    def fetch_user_details
      response = self.class.get("/users/me", headers: headers)
      handle_response(response)
    end

    def fetch_order(order_id)
      response = self.class.get("/orders/#{order_id}", headers: headers)
      handle_response(response)
    end

    def send_message_on_mercado_libre(reply_payload, pack_id, seller_id, buyer_id, text)
      response = self.class.post(
        "/messages/packs/#{pack_id}/sellers/#{seller_id}?tag=post_sale",
         headers: headers,
         body: reply_payload.to_json
        )
      handle_response(response)
    end

    def send_answer_on_mercado_libre(answer_payload)
      response = self.class.post(
        "/answers",
         headers: headers,
         body: answer_payload.to_json
        )
      handle_response(response)
    end

    # def send_attachments_on_mercado_libre(attachments)
    #   byebug
    #   attachments.each do |attachment|
    #     file_url = attachment[:file]
    #     if file_url.present?
    #       response = self.class.post(
    #         'https://api.mercadolibre.com/messages/attachments?tag=post_sale&site_id=MLA',
    #         headers: {
    #           'Authorization' => "Bearer #{ACCESS_TOKEN}", # Usamos el token adecuado
    #           'content-type' => 'multipart/form-data;'
    #         },
    #         body: {
    #           'file' => Faraday::UploadIO.new(file_url, 'image/jpeg') # Usamos Faraday para enviar el archivo
    #         }
    #       )

    #       byebug
    #       return response if response.success?
    #     else
    #       Rails.logger.error("No download URL for attachment #{attachment[:file]}")
    #     end
    #   end
    #   nil
    # end

    def valid?
      @access_token.present?
    end

    def download_file(file_url, site_id)
      response = self.class.get("/messages/attachments/#{file_url}?tag=post_sale&site_id=#{site_id}", headers: headers)
      raise StandardError, "Error descargando el archivo: #{response.code}" unless response.success?
      response.body
    end

    private

    def headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'accept' => 'application/json',
        'content-type' => 'application/json'
      }
    end

    def handle_response(response)
      Rails.logger.info("[MercadoLibre::Client] Respuesta: #{response.code} - #{response.body}")
      response.success? ? JSON.parse(response.body) : (raise StandardError, "Error in Mercado Libre request: #{response.body}")
    end
  end
end
