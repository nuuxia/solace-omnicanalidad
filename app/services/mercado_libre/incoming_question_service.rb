module MercadoLibre
  class IncomingQuestionService
    include ::FileTypeHelper
    pattr_initialize [:inbox!, :params!]

    def perform
      client = initialize_client
      process_question(client)
    end

    private

    def initialize_client
      channel = inbox.channel
      channel.ensure_token_valid
      MercadoLibre::Client.new(channel.mercado_libre_access_token)
    end

    def process_question(client)
      question_id = extract_question_id(params["resource"])
      return if question_id.blank?

      question_data = client.fetch_question_details(question_id)
      return if question_data.blank? || question_already_processed?(question_id)

      item_id = question_data["item_id"]
      item_permalink = fetch_item_permalink(client, item_id)

      set_contact(question_data)
      set_conversation(question_data, item_id, item_permalink)

      @conversation.messages.create!(
        content: question_data["text"],
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        message_type: :incoming,
        sender: @contact,
        source_id: question_id
      )
    end

    def extract_question_id(resource)
      resource&.split("/")&.last
    end

    def question_already_processed?(resource_id)
      Message.exists?(source_id: resource_id)
    end

    def fetch_item_permalink(client, item_id)
      return if item_id.blank?

      item_data = client.fetch_item_details(item_id)
      permalinks = item_data["permalinks"]
      permalinks.first["permalink"] if permalinks&.first
    end

    def set_contact(question_data)
      from_data = question_data["from"]
      client_id = from_data["id"]
      raise "Client ID not found in question data" if client_id.nil?

      contact_inbox = ::ContactInbox.find_by(source_id: client_id, inbox: inbox)

      if contact_inbox
        @contact_inbox = contact_inbox
        @contact = contact_inbox.contact
      else
        client_data = initialize_client.fetch_client_data(client_id)
        create_new_contact(client_data)
      end
    end

    def create_new_contact(client_data)
      @contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: client_data["id"].to_s,
        inbox: inbox,
        contact_attributes: contact_attributes(client_data)
      ).perform

      @contact = @contact_inbox.contact
    end

    def contact_attributes(client_data)
      address = client_data["address"] || {}
      status = client_data["status"] || {}

      {
        name: client_data["nickname"],
        identifier: client_data["id"].to_s,
        location: "#{address['city']}, #{address['state']}",
        country_code: client_data["country_id"],
        additional_attributes: {
          user_type: client_data["user_type"],
          site_status: status["site_status"]
        }
      }
    end

    def set_conversation(question_data, item_id, item_permalink)
      # Buscar una conversación existente que coincida con los mismos datos
      @conversation = @contact_inbox.conversations.detect do |conversation|
        conversation.account_id == inbox.account_id &&
        conversation.inbox_id == inbox.id &&
        conversation.contact_id == @contact.id &&
        conversation.contact_inbox_id == @contact_inbox.id &&
        conversation.additional_attributes["item_id"] == item_id &&
        conversation.additional_attributes["type_of_conversation"] == 'questions'
      end

      # Si no existe una conversación, crear una nueva
      unless @conversation
        @conversation = @contact_inbox.conversations.create!(
          conversation_params.merge(
            additional_attributes: {
              item_id: item_id,
              type_of_conversation: 'questions',
              item_permalink: item_permalink
            }
          )
        )
      end
    end

    def conversation_params
      {
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        contact_id: @contact.id,
        contact_inbox_id: @contact_inbox.id
      }
    end
  end
end
