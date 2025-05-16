module MercadoLibre
  class IncomingMessageService
    include ::FileTypeHelper
    pattr_initialize [:inbox!, :params!]

    def perform
      Rails.logger.info("[MessageService] Ejecutando IncomingMessageService para inbox #{inbox.id}")
      client = initialize_client
      fetch_and_process_new_messages(client)
    end

    private

    def initialize_client
      channel = inbox.channel
      channel.ensure_token_valid
      MercadoLibre::Client.new(channel.mercado_libre_access_token)
    end

    def fetch_and_process_new_messages(client)
      Rails.logger.info("[MessageService] Fetching mensajes con resource #{params['resource']}")
      new_messages = client.fetch_new_messages(params)

      if new_messages["messages"].blank?
        Rails.logger.warn("[MessageService] No se encontraron mensajes nuevos")
        return
      end

      new_messages["messages"].each do |message|
        Rails.logger.info("[MessageService] Procesando mensaje con ID #{message['id']}")
        next if message_from_channel_owner?(message)

        process_message(message, client)
      end
    end

    def message_from_channel_owner?(message)
      channel_user_id = inbox.channel.mercado_libre_user_id
      message_sender_id = message["from"]["user_id"]
      channel_user_id.to_s == message_sender_id.to_s
    end

    def process_message(message, client)
      Rails.logger.info("[MessageService] Creando mensaje desde #{message['from']['user_id']}")
      pack_id = extract_pack_id(message)
      set_contact(message)
      set_conversation(pack_id, message, client)

      @conversation.messages.create!(
        content: message["text"],
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        message_type: :incoming,
        sender: @contact,
        source_id: message["id"]
      )

      process_attachments(message["message_attachments"], client, message['site_id'])
    end

    def extract_pack_id(message)
      message["message_resources"]&.find { |resource| resource["name"] == "packs" }&.dig("id")
    end

    def set_contact(message)
      client_id = message["from"]["user_id"]
      client_data = initialize_client.fetch_client_data(client_id)

      contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: client_id,
        inbox: inbox,
        contact_attributes: contact_attributes(client_data)
      ).perform

      @contact_inbox = contact_inbox
      @contact = contact_inbox.contact
    end

    def contact_attributes(client_data)
      {
        name: client_data['nickname'],
        identifier: client_data['id'].to_s,
        location: "#{client_data['address']['city']}, #{client_data['address']['state']}",
        country_code: client_data['country_id'],
        additional_attributes: {
          user_type: client_data['user_type'],
          site_status: client_data['status']['site_status']
        }
      }
    end

    def set_conversation(pack_id, message, client)
      # Accediendo a los valores de buyer_id y seller_id
      buyer_id = message["from"]["user_id"]
      seller_id = message["to"]["user_id"]

      # Buscar una conversación existente que coincida con los mismos datos
      @conversation = @contact_inbox.conversations.detect do |conversation|
        conversation.account_id == inbox.account_id &&
        conversation.inbox_id == inbox.id &&
        conversation.contact_id == @contact.id &&
        conversation.contact_inbox_id == @contact_inbox.id &&
        conversation.additional_attributes["pack_id"] == pack_id &&
        conversation.additional_attributes["buyer_id"] == buyer_id &&
        conversation.additional_attributes["seller_id"] == seller_id &&
        conversation.additional_attributes["type_of_conversation"] == 'post_sale'
      end

      # Si no existe, crear una nueva conversación
      unless @conversation
        @conversation = @contact_inbox.conversations.create!(
          conversation_params.merge(
            additional_attributes: {
              pack_id: pack_id,
              buyer_id: buyer_id,
              seller_id: seller_id,
              type_of_conversation: 'post_sale'
            }
          )
        )
      end

      # Agregar detalles de orden si no están presentes
      if pack_id.present? && @conversation.additional_attributes["order_details"].blank?
        order_details = fetch_order_details(client, pack_id)
        if order_details
          @conversation.update!(
            additional_attributes: @conversation.additional_attributes.merge(order_details: order_details)
          )
        end
      end
    end

    def fetch_order_details(client, pack_id)
      MercadoLibre::FetchOrderService.new(client: client, order_id: pack_id).perform
    rescue StandardError => e
      Rails.logger.error("Error fetching order #{pack_id}: #{e.message}")
      nil
    end

    def update_conversation_with_order_details(order_details)
      @conversation.update!(
        additional_attributes: @conversation.additional_attributes.merge(
          order_details: order_details
        )
      )
    end

    def conversation_params
      {
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        contact_id: @contact.id,
        contact_inbox_id: @contact_inbox.id
      }
    end

    def process_attachments(attachments, client, site_id)
      return if attachments.blank?

      attachments.each do |attachment|
        next if attachment["potential_security_threat"]

        downloaded_file = download_attachment(attachment, client, site_id)

        attach_file_to_conversation(downloaded_file, attachment) if downloaded_file
      end
    end

    def download_attachment(attachment, client, site_id)
      file_content = client.download_file(attachment["filename"], site_id)
      return nil unless file_content

      file_name = "attachment-#{attachment['id']}.#{attachment['type'].split('/').last}"
      temp_file = Tempfile.new(file_name)
      temp_file.binmode
      temp_file.write(file_content)
      temp_file.rewind
      temp_file
    rescue StandardError => e
      Rails.logger.error("Error downloading Mercado Libre attachment #{attachment['filename']}: #{e.message}")
      nil
    end

    def attach_file_to_conversation(file, attachment)
      @conversation.messages.last.attachments.create!(
        account_id: inbox.account_id,
        file_type: file_content_type(attachment),
        file: {
          io: file,
          filename: attachment["original_filename"] || "attachment-#{attachment['id']}",
          content_type: attachment["type"]
        }
      )
    ensure
      file.close
      file.unlink
    end

    def file_content_type(attachment)
      case attachment["type"]
      when /image/ then :image
      when /video/ then :video
      when /audio/ then :audio
      else
        :file
      end
    end
  end
end
