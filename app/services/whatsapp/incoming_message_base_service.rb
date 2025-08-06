# Mostly modeled after the intial implementation of the service based on 360 Dialog
# https://docs.360dialog.com/whatsapp-api/whatsapp-api/media
# https://developers.facebook.com/docs/whatsapp/api/media/
class Whatsapp::IncomingMessageBaseService
  include ::Whatsapp::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    processed_params

    if processed_params.try(:[], :statuses).present?
      process_statuses
    elsif processed_params.try(:[], :message_echoes).present?
      process_message_echoes
    elsif processed_params.try(:[], :messages).present?
      process_messages
    end
  end

  private

  def process_messages
    # We don't support reactions & ephemeral message now, we need to skip processing the message
    # if the webhook event is a reaction or an ephermal message or an unsupported message.
    return if unprocessable_message_type?(message_type)

    # Multiple webhook event can be received against the same message due to misconfigurations in the Meta
    # business manager account. While we have not found the core reason yet, the following line ensure that
    # there are no duplicate messages created.
    return if find_message_by_source_id(@processed_params[:messages].first[:id]) || message_under_process?

    cache_message_source_id_in_redis
    set_contact
    return unless @contact

    set_conversation
    create_messages
    clear_message_source_id_from_redis
  end

  def process_statuses
    return unless find_message_by_source_id(@processed_params[:statuses].first[:id])

    update_message_with_status(@message, @processed_params[:statuses].first)
  rescue ArgumentError => e
    Rails.logger.error "Error while processing whatsapp status update #{e.message}"
  end

  def process_message_echoes
    # Process message echoes as outgoing messages from WhatsApp Business
    echo_message = @processed_params[:message_echoes].first
    return if echo_message.blank?

    # Find or create contact based on the recipient (to) phone number
    set_contact_for_echo(echo_message)
    return unless @contact

    # Set conversation for the contact
    set_conversation

    # Create the outgoing message
    create_echo_message(echo_message)
  end

  def update_message_with_status(message, status)
    message.status = status[:status]
    if status[:status] == 'failed' && status[:errors].present?
      error = status[:errors]&.first
      message.external_error = "#{error[:code]}: #{error[:title]}"
    end
    message.save!
  end

  def create_messages
    message = @processed_params[:messages].first
    log_error(message) && return if error_webhook_event?(message)

    process_in_reply_to(message)

    message_type == 'contacts' ? create_contact_messages(message) : create_regular_message(message)
  end

  def create_contact_messages(message)
    message['contacts'].each do |contact|
      create_message(contact)
      attach_contact(contact)
      @message.save!
    end
  end

  def create_regular_message(message)
    create_message(message)
    attach_files
    attach_location if message_type == 'location'
    @message.save!
  end

  def set_contact
    contact_params = @processed_params[:contacts]&.first
    return if contact_params.blank?

    waid = processed_waid(contact_params[:wa_id])

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: waid,
      inbox: inbox,
      contact_attributes: { name: contact_params.dig(:profile, :name), phone_number: "+#{@processed_params[:messages].first[:from]}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    # if lock to single conversation is disabled, we will create a new conversation if previous conversation is resolved
    @conversation = if @inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations
                                    .where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end

  def attach_files
    return if %w[text button interactive location contacts].include?(message_type)

    attachment_payload = @processed_params[:messages].first[message_type.to_sym]
    @message.content ||= attachment_payload[:caption]

    attachment_file = download_attachment_file(attachment_payload)
    return if attachment_file.blank?

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  end

  def attach_location
    location = @processed_params[:messages].first['location']
    location_name = location['name'] ? "#{location['name']}, #{location['address']}" : ''
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      coordinates_lat: location['latitude'],
      coordinates_long: location['longitude'],
      fallback_title: location_name,
      external_url: location['url']
    )
  end

  def create_message(message)
    @message = @conversation.messages.build(
      content: message_content(message),
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: message[:id].to_s,
      in_reply_to_external_id: @in_reply_to_external_id
    )
  end

  def attach_contact(contact)
    phones = contact[:phones]
    phones = [{ phone: 'Phone number is not available' }] if phones.blank?

    name_info = contact['name'] || {}
    contact_meta = {
      firstName: name_info['first_name'],
      lastName: name_info['last_name']
    }.compact

    phones.each do |phone|
      @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_content_type(message_type),
        fallback_title: phone[:phone].to_s,
        meta: contact_meta
      )
    end
  end

  def set_contact_for_echo(echo_message)
    # For echo messages, the 'to' field contains the contact's phone number
    recipient_phone = echo_message[:to]
    return if recipient_phone.blank?

    # Find or create contact by phone number
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: recipient_phone,
      inbox: inbox,
      contact_attributes: { phone_number: "+#{recipient_phone}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def create_echo_message(echo_message)
    # Check if message already exists to prevent duplicates
    return if find_message_by_source_id(echo_message[:id])

    begin
      # Create the outgoing message
      @message = @conversation.messages.build(
        content: message_content_for_echo(echo_message) || '', # Ensure content is never nil
        account_id: @inbox.account_id,
        inbox_id: @inbox.id,
        message_type: :outgoing,
        sender: nil, # Agent message
        source_id: echo_message[:id].to_s,
        status: :sent
      )

      # Handle attachments if present
      if echo_message[:type] != 'text'
        attach_echo_files(echo_message)
        # For image messages without caption, set a default content
        @message.content = '' if @message.content.blank? && echo_message[:type] == 'image'
      end

      # Only save if message is valid
      if @message.valid?
        @message.save!
      else
        Rails.logger.error "Invalid echo message: #{@message.errors.full_messages}"
      end
    rescue StandardError => e
      Rails.logger.error "Error creating echo message: #{e.message}"
    end
  end

  def message_content_for_echo(echo_message)
    # Extract content based on message type
    case echo_message[:type]
    when 'text'
      echo_message.dig(:text, :body)
    when 'button'
      echo_message.dig(:button, :text)
    when 'interactive'
      echo_message.dig(:interactive, :button_reply, :title) ||
        echo_message.dig(:interactive, :list_reply, :title)
    when 'image'
      echo_message.dig(:image, :caption) # Images can have captions
    when 'video'
      echo_message.dig(:video, :caption) # Videos can have captions
    when 'document'
      echo_message.dig(:document, :caption) # Documents can have captions
    when 'sticker'
      nil # Stickers don't have captions, content is in the attachment
    when 'contacts'
      # Extract contact names for message content
      contacts = echo_message[:contacts] || []
      names = contacts.map { |contact| contact.dig(:name, :formatted_name) }.compact
      names.any? ? "Contact: #{names.join(', ')}" : 'Contact'
    when 'location'
      # Extract location info for message content
      location = echo_message[:location]
      location['name'] || location['address'] || 'Location'

    else
      nil # For other media messages, content will be in attachments
    end
  end

  def attach_echo_files(echo_message)
    return if echo_message[:type] == 'text'
    return unless echo_message[:type].present?

    # Handle different media types
    case echo_message[:type]
    when 'image', 'audio', 'video', 'document', 'sticker'
      attach_echo_media_file(echo_message)
    when 'location'
      attach_echo_location(echo_message)
    when 'contacts'
      attach_echo_contacts(echo_message)
    end
  rescue StandardError => e
    Rails.logger.error "Error attaching echo files: #{e.message}"
    # Continue without attachment rather than failing the entire message
  end

  def attach_echo_media_file(echo_message)
    media_data = echo_message[echo_message[:type].to_sym]
    return unless media_data

    begin
      # Download the attachment file using WhatsApp API
      attachment_file = download_attachment_file(media_data)
      return unless attachment_file.present?

      # Only create attachment if download was successful
      @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_content_type(echo_message[:type]),
        file: {
          io: attachment_file,
          filename: attachment_file.original_filename || "file.#{echo_message[:type]}",
          content_type: attachment_file.content_type || media_data[:mime_type]
        }
      )
    rescue StandardError => e
      Rails.logger.error "Error downloading echo attachment: #{e.message}"
      # Skip attachment creation on error - better to have message without attachment than broken frontend
      return
    end
  end

  def attach_echo_location(echo_message)
    location = echo_message[:location]
    return unless location

    location_name = location['name'] ? "#{location['name']}, #{location['address']}" : ''
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type('location'),
      coordinates_lat: location['latitude'],
      coordinates_long: location['longitude'],
      fallback_title: location_name,
      external_url: location['url']
    )
  end

  def attach_echo_contacts(echo_message)
    contacts = echo_message[:contacts]
    return unless contacts.present?

    # Handle multiple contacts in the echo message
    contacts.each do |contact|
      phones = contact[:phones]
      phones = [{ phone: 'Phone number is not available' }] if phones.blank?

      name_info = contact[:name] || {}
      contact_meta = {
        firstName: name_info[:first_name],
        lastName: name_info[:last_name]
      }.compact

      phones.each do |phone|
        @message.attachments.new(
          account_id: @message.account_id,
          file_type: file_content_type('contacts'),
          fallback_title: phone[:phone].to_s,
          meta: contact_meta
        )
      end
    end
  end
end
