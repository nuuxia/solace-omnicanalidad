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
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_alert(params)
    action_params = params[:action_params] || {}

    inbox = @account.inboxes.find_by(id: action_params[:inbox_id])
    Rails.logger.info "📥 Inbox found: #{inbox.inspect}" if inbox.present?
    raise 'Inbox not found' if inbox.blank?

    template = inbox.channel&.message_templates&.find { |t| t['id'] == action_params[:template_id] }
    raise 'Invalid template' if template.blank?

    phone_number = action_params[:phone_number]
    raise 'Phone number is required' if phone_number.blank?

    Whatsapp::CampaignPreviewService.new(
      inbox: inbox,
      template: template,
      phone_number: phone_number
    ).perform

    Rails.logger.info "✅ WhatsApp alert sent successfully to #{phone_number}"
  rescue StandardError => e
    Rails.logger.error "❌ Error sending WhatsApp alert: #{e.message}"
  end

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
