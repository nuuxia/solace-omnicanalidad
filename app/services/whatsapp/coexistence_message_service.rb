# frozen_string_literal: true

# This service handles messages sent from coexistent WhatsApp devices
# It ensures that messages sent from other devices are properly recorded in Arrows
class Whatsapp::CoexistenceMessageService
  include ::Whatsapp::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] INICIO perform. params[:entry]=#{params[:entry].inspect}")

    # Validar que los parámetros existen
    if params.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] perform - params está vacío')
      return
    end

    if params[:entry].blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] perform - params[:entry] está vacío')
      return
    end

    processed_params

    # Only process messages, not statuses
    unless messages_array.present?
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] NO messages_array.present? - params: #{params.inspect}")
      return
    end

    # Validar que el primer mensaje existe
    if messages_array.first.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] perform - messages_array.first está vacío')
      return
    end

    # Check if this is a message from a coexistent device
    unless from_coexistent_device?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] NO es mensaje coexistente. sender=#{messages_array.first[:from]}, channel_number=#{inbox.channel.phone_number.delete('+')}")
      return
    end

    # Check for duplicate messages
    if find_message_by_source_id(messages_array.first[:id])
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] Mensaje duplicado detectado. source_id=#{messages_array.first[:id]}")
      return
    end

    # Check if message is under process
    if message_under_process?
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] Mensaje bajo proceso. source_id=#{messages_array.first[:id]}")
      return
    end

    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Procesando mensaje coexistente: source_id=#{messages_array.first[:id]}, content=#{messages_array.first.dig(
      :text, :body
    )}")

    # Cache the message source id to prevent duplicate processing
    cache_message_source_id_in_redis

    # Process the message
    process_coexistent_message

    # Clear the cache after processing
    clear_message_source_id_from_redis
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en perform: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    clear_message_source_id_from_redis
    raise e
  end

  private

  def processed_params
    @processed_params ||= params[:entry].try(:first).try(:[], 'changes').try(:first).try(:[], 'value')
  end

  def messages_array
    @messages_array ||= begin
      messages = processed_params[:messages] ||
                 processed_params[:message_echoes] ||
                 processed_params['messages'] ||
                 processed_params['message_echoes'] ||
                 []

      Rails.logger.info("[Whatsapp::CoexistenceMessageService] messages_array: #{messages.inspect}")
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] processed_params keys: #{processed_params.keys.inspect}")
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] processed_params[:messages]: #{processed_params[:messages].inspect}")
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] processed_params[:message_echoes]: #{processed_params[:message_echoes].inspect}")

      messages
    end
  end

  def from_coexistent_device?
    return false unless messages_array.first&.dig(:from).present?

    sender_number = messages_array.first[:from]
    channel_number = inbox.channel.phone_number.delete('+')
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] from_coexistent_device? sender_number=#{sender_number}, channel_number=#{channel_number}")
    result = sender_number == channel_number
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] from_coexistent_device? result=#{result}")
    result
  end

  def process_coexistent_message
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Iniciando process_coexistent_message para message_id=#{messages_array.first[:id]}")
    # We don't support reactions & ephemeral message now, we need to skip processing the message
    # if the webhook event is a reaction or an ephermal message or an unsupported message.
    return if unprocessable_message_type?(message_type)

    # Multiple webhook event can be received against the same message due to misconfigurations in the Meta
    # business manager account. While we have not found the core reason yet, the following line ensure that
    # there are no duplicate messages created.
    # NOTA: Las verificaciones de duplicados ya se hacen en perform(), no es necesario repetirlas aquí

    # For coexistent devices, we need to find the contact that matches the recipient
    # instead of the sender (which would be the same as the channel's number)
    set_contact_for_coexistent_device
    unless @contact
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] No se encontró o creó el contacto para recipient_id=#{messages_array.first[:to]}. Abortando creación de mensaje coexistente.")
      return
    end

    set_conversation
    create_messages
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Mensaje coexistente procesado correctamente para message_id=#{messages_array.first[:id]}")
  end

  def message_type
    @message_type ||= determine_message_type(messages_array.first)
  end

  def set_contact_for_coexistent_device
    recipient_id = messages_array.first[:to]
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Buscando ContactInbox para recipient_id=#{recipient_id} en inbox_id=#{inbox.id}")

    if recipient_id.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] set_contact_for_coexistent_device - recipient_id está vacío')
      return
    end

    # Validar que el inbox existe
    if inbox.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] set_contact_for_coexistent_device - inbox está vacío')
      return
    end

    contact_inbox = inbox.contact_inboxes.find_by(source_id: recipient_id)
    if contact_inbox.blank?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] No existe ContactInbox para recipient_id=#{recipient_id}, creando nuevo contacto...")

      begin
        contact_inbox = ::ContactInboxWithContactBuilder.new(
          source_id: recipient_id,
          inbox: inbox,
          contact_attributes: { phone_number: "+#{recipient_id}" }
        ).perform

        if contact_inbox.persisted?
          Rails.logger.info("[Whatsapp::CoexistenceMessageService] ContactInbox creado correctamente para recipient_id=#{recipient_id}, contact_id=#{contact_inbox.contact_id}")
        else
          Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error al crear ContactInbox para recipient_id=#{recipient_id}: #{contact_inbox.errors.full_messages}")
          return
        end
      rescue StandardError => e
        Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error al crear ContactInbox: #{e.message}")
        return
      end
    else
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] ContactInbox encontrado para recipient_id=#{recipient_id}, contact_id=#{contact_inbox.contact_id}")
    end

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    if @contact.nil?
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] Contacto es nil para recipient_id=#{recipient_id}")
      return
    end

    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Contacto configurado correctamente: contact_id=#{@contact.id}")
  end

  def set_conversation
    # Validar que el contact_inbox existe
    if @contact_inbox.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] set_conversation - @contact_inbox está vacío')
      return
    end

    @conversation = @contact_inbox.conversations.last
    return if @conversation.present?

    Rails.logger.info('[Whatsapp::CoexistenceMessageService] No existe conversación, creando nueva...')

    begin
      @conversation = ::Conversation.create!(conversation_params)
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] Conversación creada correctamente: conversation_id=#{@conversation.id}")
    rescue StandardError => e
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error al crear conversación: #{e.message}")
      raise e
    end
  end

  def conversation_params
    # Validar que los parámetros necesarios existen
    if @inbox.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] conversation_params - @inbox está vacío')
      raise StandardError, 'Inbox no puede estar vacío'
    end

    if @contact.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] conversation_params - @contact está vacío')
      raise StandardError, 'Contact no puede estar vacío'
    end

    if @contact_inbox.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] conversation_params - @contact_inbox está vacío')
      raise StandardError, 'ContactInbox no puede estar vacío'
    end

    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { type: 'whatsapp' }
    }
  end

  def create_messages
    message = messages_array.first
    log_error(message) && return if error_webhook_event?(message)

    process_in_reply_to(message)

    case message_type
    when 'text'
      create_regular_message(message)
    when 'image', 'audio', 'video', 'document', 'sticker'
      create_attachment_message(message)
    when 'location'
      create_location_message(message)
    when 'contacts'
      create_contact_message(message)
    when 'interactive'
      create_regular_message(message)
    when 'template', 'reaction', 'order', 'system'
      create_regular_message(message)
    else
      create_regular_message(message)
    end
  end

  def create_regular_message(message)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Intentando crear mensaje regular coexistente: conversation_id=#{@conversation.id}, source_id=#{message[:id]}")
    create_message(message)
    attach_files
    @message.save!
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Mensaje regular coexistente creado exitosamente: id=#{@message.id}")
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en create_regular_message: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    raise e
  end

  def create_attachment_message(message)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Intentando crear mensaje con adjunto coexistente: conversation_id=#{@conversation.id}, source_id=#{message[:id]}")
    create_message(message)
    attach_files
    @message.save!
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Mensaje con adjunto coexistente creado exitosamente: id=#{@message.id}")
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en create_attachment_message: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    raise e
  end

  def create_location_message(message)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Intentando crear mensaje de ubicación coexistente: conversation_id=#{@conversation.id}, source_id=#{message[:id]}")
    create_message(message)
    attach_location
    @message.save!
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Mensaje de ubicación coexistente creado exitosamente: id=#{@message.id}")
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en create_location_message: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    raise e
  end

  def create_contact_message(message)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Intentando crear mensaje de contacto coexistente: conversation_id=#{@conversation.id}, source_id=#{message[:id]}")
    create_message(message)
    create_contact_messages(message)
    @message.save!
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Mensaje de contacto coexistente creado exitosamente: id=#{@message.id}")
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en create_contact_message: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    raise e
  end

  def download_attachment_file(attachment_payload)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] download_attachment_file - attachment_payload=#{attachment_payload.inspect}")

    # Validar que el attachment_payload tiene un ID
    if attachment_payload[:id].blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] download_attachment_file - attachment_payload no tiene ID')
      return nil
    end

    # Validar que el inbox y channel existen
    if inbox.blank? || inbox.channel.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] download_attachment_file - inbox o channel no existe')
      return nil
    end

    # Obtener la URL del archivo
    media_url = inbox.channel.media_url(attachment_payload[:id])
    if media_url.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] download_attachment_file - media_url está vacío')
      return nil
    end

    Rails.logger.info("[Whatsapp::CoexistenceMessageService] download_attachment_file - media_url=#{media_url}")

    # Descargar la información del archivo
    url_response = HTTParty.get(media_url, headers: inbox.channel.api_headers)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] download_attachment_file - url_response.status=#{url_response.code}")

    # This url response will be failure if the access token has expired.
    if url_response.unauthorized?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] download_attachment_file - Token de autorización expirado')
      inbox.channel.authorization_error!
      return nil
    end

    if url_response.success?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] download_attachment_file - url_response.parsed_response=#{url_response.parsed_response.inspect}")

      # Validar que la respuesta tiene una URL
      if url_response.parsed_response['url'].blank?
        Rails.logger.error('[Whatsapp::CoexistenceMessageService] download_attachment_file - La respuesta no contiene URL')
        return nil
      end

      # Descargar el archivo
      downloaded_file = Down.download(url_response.parsed_response['url'], headers: inbox.channel.api_headers)
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] download_attachment_file - downloaded_file=#{downloaded_file.inspect}")

      # Validar que el archivo se descargó correctamente
      if downloaded_file.blank?
        Rails.logger.error('[Whatsapp::CoexistenceMessageService] download_attachment_file - No se pudo descargar el archivo')
        return nil
      end

      return downloaded_file
    else
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] download_attachment_file - Error en descarga: #{url_response.code} - #{url_response.body}")
      return nil
    end
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en download_attachment_file: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    return nil
  end

  def create_message(message)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Intentando crear mensaje regular coexistente: conversation_id=#{@conversation.id}, source_id=#{messages_array.first[:id]}")

    # Validar que el mensaje existe
    if message.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] create_message - message está vacío')
      raise StandardError, 'Message no puede estar vacío'
    end

    # Validar que el conversation existe
    if @conversation.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] create_message - @conversation está vacío')
      raise StandardError, 'Conversation no puede estar vacío'
    end

    # Validar que el source_id existe
    if message[:id].blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] create_message - message[:id] está vacío')
      raise StandardError, 'Message ID no puede estar vacío'
    end

    # Obtener el contenido del mensaje
    content = message_content(message)

    # Si hay un adjunto con caption, agregarlo al contenido
    if message_type != 'text' && message_type != 'button' && message_type != 'interactive'
      attachment_payload = message[message_type.to_sym]
      if attachment_payload&.dig(:caption).present?
        content = attachment_payload[:caption]
        Rails.logger.info("[Whatsapp::CoexistenceMessageService] Usando caption del adjunto: #{content}")
      end
    end

    @message = @conversation.messages.build(
      content: content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :outgoing, # Mensaje saliente
      sender: nil, # <--- Usar nil para que aparezca como mensaje del sistema, igual que en Instagram
      source_id: message[:id].to_s,
      in_reply_to_external_id: @in_reply_to_external_id
    )

    # Validar que el mensaje se creó correctamente
    if @message.valid?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] Mensaje creado: id=#{@message.id}, conversation_id=#{@message.conversation_id}, message_type=#{@message.message_type}")
      Rails.logger.info('[Whatsapp::CoexistenceMessageService] Mensaje guardado exitosamente, callbacks deberían ejecutarse')
    else
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] create_message - Error de validación en mensaje: #{@message.errors.full_messages}")
      raise StandardError, "Error de validación en mensaje: #{@message.errors.full_messages}"
    end

    @message
  end

  def attach_files
    return if %w[text button interactive location contacts].include?(message_type)

    Rails.logger.info("[Whatsapp::CoexistenceMessageService] attach_files - message_type=#{message_type}")

    attachment_payload = messages_array.first[message_type.to_sym]
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] attach_files - attachment_payload=#{attachment_payload.inspect}")

    # Validar que el attachment_payload existe
    if attachment_payload.blank?
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] attach_files - attachment_payload está vacío para message_type=#{message_type}")
      return
    end

    # Validar que el attachment_payload tiene un ID
    if attachment_payload[:id].blank?
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] attach_files - attachment_payload no tiene ID: #{attachment_payload.inspect}")
      return
    end

    attachment_file = download_attachment_file(attachment_payload)
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] attach_files - attachment_file=#{attachment_file.inspect}")

    if attachment_file.blank?
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] attach_files - No se pudo descargar el archivo para message_type=#{message_type}")
      return
    end

    Rails.logger.info("[Whatsapp::CoexistenceMessageService] attach_files - Creando attachment con file_type=#{file_content_type(message_type)}")

    # Usar new en lugar de create! para seguir el patrón estándar
    attachment = @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )

    # Validar que el attachment se creó correctamente
    if attachment.valid?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] Adjunto creado para mensaje coexistente: message_id=#{@message.id}, attachment_id=#{attachment.id}, file_type=#{attachment.file_type}")
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] attach_files - Adjunto creado exitosamente: id=#{attachment.id}, file_type=#{attachment.file_type}, file_attached=#{attachment.file.attached?}")
    else
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] attach_files - Error de validación en attachment: #{attachment.errors.full_messages}")
      raise StandardError, "Error de validación en attachment: #{attachment.errors.full_messages}"
    end
  rescue StandardError => e
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en attach_files: #{e.message}")
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Backtrace: #{e.backtrace.join("\n")}")
    raise e
  end

  def attach_location
    location = messages_array.first['location']

    # Validar que la ubicación existe
    if location.blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] attach_location - location está vacío')
      return
    end

    # Validar que los campos requeridos existen
    if location['latitude'].blank? || location['longitude'].blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] attach_location - latitude o longitude están vacíos')
      return
    end

    location_name = location['name'] ? "#{location['name']}, #{location['address']}" : ''

    attachment = @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type(message_type),
      coordinates_lat: location['latitude'],
      coordinates_long: location['longitude'],
      fallback_title: location_name,
      external_url: location['url']
    )

    # Validar que el attachment se creó correctamente
    if attachment.valid?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] Ubicación creada para mensaje coexistente: message_id=#{@message.id}")
    else
      Rails.logger.error("[Whatsapp::CoexistenceMessageService] attach_location - Error de validación en attachment: #{attachment.errors.full_messages}")
      raise StandardError, "Error de validación en attachment de ubicación: #{attachment.errors.full_messages}"
    end
  end

  def create_contact_messages(message)
    # Validar que el mensaje existe
    if message.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] create_contact_messages - message está vacío')
      return
    end

    # Validar que los contactos existen
    if message['contacts'].blank?
      Rails.logger.warn("[Whatsapp::CoexistenceMessageService] create_contact_messages - message['contacts'] está vacío")
      return
    end

    message['contacts'].each do |contact|
      attach_contact(contact)
    end
    Rails.logger.info("[Whatsapp::CoexistenceMessageService] Contactos creados para mensaje coexistente: message_id=#{@message.id}")
  end

  def attach_contact(contact)
    # Validar que el contacto existe
    if contact.blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] attach_contact - contact está vacío')
      return
    end

    phones = contact[:phones]
    phones = [{ phone: 'Phone number is not available' }] if phones.blank?

    phones.each do |phone|
      # Validar que el phone existe
      if phone.blank?
        Rails.logger.warn('[Whatsapp::CoexistenceMessageService] attach_contact - phone está vacío')
        next
      end

      attachment = @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_content_type(message_type),
        fallback_title: phone[:phone].to_s
      )

      # Validar que el attachment se creó correctamente
      if attachment.valid?
        Rails.logger.info("[Whatsapp::CoexistenceMessageService] Contact attachment creado: phone=#{phone[:phone]}")
      else
        Rails.logger.error("[Whatsapp::CoexistenceMessageService] attach_contact - Error de validación en attachment: #{attachment.errors.full_messages}")
        raise StandardError, "Error de validación en attachment de contacto: #{attachment.errors.full_messages}"
      end
    end
  end

  def find_message_by_source_id(source_id)
    # Validar que el source_id existe
    if source_id.blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] find_message_by_source_id - source_id está vacío')
      return nil
    end

    # Buscar en la base de datos por source_id
    message = Message.find_by(source_id: source_id.to_s)

    if message.present?
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] find_message_by_source_id - Mensaje encontrado: id=#{message.id}")
    else
      Rails.logger.info("[Whatsapp::CoexistenceMessageService] find_message_by_source_id - Mensaje no encontrado para source_id=#{source_id}")
    end

    message
  end

  def message_content(message)
    # Validar que el mensaje existe
    if message.blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] message_content - message está vacío')
      return ''
    end

    if message[:text].present?
      message[:text][:body]
    elsif message['text'].present?
      message['text']['body']
    elsif message[:interactive].present? && message[:interactive][:button_reply].present?
      message[:interactive][:button_reply][:title]
    elsif message['interactive'].present? && message['interactive']['button_reply'].present?
      message['interactive']['button_reply']['title']
    elsif message[:interactive].present? && message[:interactive][:list_reply].present?
      message[:interactive][:list_reply][:title]
    elsif message['interactive'].present? && message['interactive']['list_reply'].present?
      message['interactive']['list_reply']['title']
    else
      ''
    end

    # NO agregar contenido de texto para adjuntos - dejar que el frontend los renderice
    # Solo agregar contenido si realmente hay texto del usuario
  end

  def file_content_type(message_type)
    case message_type
    when 'image', 'sticker'
      'image'
    when 'audio'
      'audio'
    when 'video'
      'video'
    when 'document'
      'file'
    when 'location'
      'location'
    when 'contacts'
      'contact'
    when 'interactive'
      'file'  # Usar 'file' para interactive ya que no existe tipo específico
    when 'template'
      'file'  # Usar 'file' para template ya que no existe tipo específico
    when 'reaction'
      'file'  # Usar 'file' para reaction ya que no existe tipo específico
    when 'order'
      'file'  # Usar 'file' para order ya que no existe tipo específico
    when 'system'
      'file'  # Usar 'file' para system ya que no existe tipo específico
    else
      'file'
    end
  end

  def error_webhook_event?(message)
    # Validar que el mensaje existe
    if message.blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] error_webhook_event? - message está vacío')
      return false
    end

    message[:errors].present? || message['errors'].present?
  end

  def log_error(message)
    # Validar que el mensaje existe
    if message.blank?
      Rails.logger.error('[Whatsapp::CoexistenceMessageService] log_error - message está vacío')
      return
    end

    error_message = message[:errors] || message['errors']
    Rails.logger.error("[Whatsapp::CoexistenceMessageService] Error en webhook: #{error_message}")
  end

  def process_in_reply_to(message)
    # Validar que el mensaje existe
    if message.blank?
      Rails.logger.warn('[Whatsapp::CoexistenceMessageService] process_in_reply_to - message está vacío')
      return
    end

    @in_reply_to_external_id = message[:context]&.dig(:id) || message['context']&.dig('id')

    return unless @in_reply_to_external_id.present?

    Rails.logger.info("[Whatsapp::CoexistenceMessageService] process_in_reply_to - in_reply_to_external_id=#{@in_reply_to_external_id}")
  end
end
