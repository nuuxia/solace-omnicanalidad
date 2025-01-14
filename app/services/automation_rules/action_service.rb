class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        # Log para verificar el action_name y params
        Rails.logger.info "Processing action: #{action[:action_name]} with params: #{action[:action_params]}"

        # Llamar directamente al método usando send
        if respond_to?(action[:action_name], true)
          Rails.logger.info "Calling action method: #{action[:action_name]}"
          send(action[:action_name], action[:action_params])
        else
          raise "Action #{action[:action_name]} not implemented"
        end
      rescue StandardError => e
        Rails.logger.error "❌ Error processing action #{action[:action_name]}: #{e.message}"
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  # Método send_alert público para facilitar pruebas y monitoreo
  def send_alert(action_params)
    Rails.logger.info "Inside send_alert method with params: #{action_params}"

    inbox = @account.inboxes.find_by(id: action_params[:inbox_id])
    raise 'Inbox not found' if inbox.blank?

    template = inbox.channel&.message_templates&.find { |t| t['id'] == action_params[:template_id] }
    raise 'Invalid template' if template.blank?

    phone_number = action_params[:phone_number]
    raise 'Phone number is required' if phone_number.blank?

    Rails.logger.info "Sending WhatsApp alert to phone number: #{phone_number}"

    # Realiza la llamada al servicio de WhatsApp
    Whatsapp::CampaignPreviewService.new(
      inbox: inbox,
      template: template,
      phone_number: phone_number
    ).perform

    Rails.logger.info "✅ WhatsApp alert sent successfully to #{phone_number}"
  rescue StandardError => e
    Rails.logger.error "❌ Error sending WhatsApp alert: #{e.message}"
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
    end
  end
end
