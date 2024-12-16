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

      item_id = question_data.dig("item_id")
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
      item_data = item_data["permalinks"].first["permalink"]
      item_data
    end

    def set_contact(question_data)
      client_id = question_data["user_id"] || params["user_id"]
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
      {
        name: client_data["nickname"],
        identifier: client_data["id"].to_s,
        location: "#{client_data.dig("address", "city")}, #{client_data.dig("address", "state")}",
        country_code: client_data["country_id"],
        additional_attributes: {
          user_type: client_data["user_type"],
          site_status: client_data.dig("status", "site_status")
        }
      }
    end

    def set_conversation(question_data, item_id, item_permalink)
      pack_id = question_data.dig("pack_id")
      buyer_id = question_data.dig("buyer_id")
      seller_id = question_data.dig("seller_id")
      type_of_conversation = "questions"

      @conversation = @contact_inbox.conversations.find_or_initialize_by(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        contact_id: @contact.id,
        contact_inbox_id: @contact_inbox.id
      )


      @conversation.additional_attributes ||= {}
      @conversation.additional_attributes.merge!(
        pack_id: pack_id,
        buyer_id: buyer_id,
        seller_id: seller_id,
        type_of_conversation: type_of_conversation,
        item_id: item_id,
        item_permalink: item_permalink
      )

      @conversation.save!
    end
  end
end
