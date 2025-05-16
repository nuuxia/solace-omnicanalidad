class AgentBotListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    unless should_process_conversation?(conversation)
      maybe_mark_as_open_if_skipped(conversation)
      return
    end

    event_name = __method__.to_s
    payload = conversation.webhook_data.merge(event: event_name)
    process_webhook_bot_event(inbox.agent_bot, payload)
  end

  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    unless should_process_conversation?(conversation)
      maybe_mark_as_open_if_skipped(conversation)
      return
    end

    event_name = __method__.to_s
    payload = conversation.webhook_data.merge(event: event_name)
    process_webhook_bot_event(inbox.agent_bot, payload)
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation
    inbox = message.inbox

    return unless message.webhook_sendable?
    unless should_process_conversation?(conversation)
      maybe_mark_as_open_if_skipped(conversation)
      return
    end

    method_name = __method__.to_s
    process_message_event(method_name, inbox.agent_bot, message, event)
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation
    inbox = message.inbox

    return unless message.webhook_sendable?
    unless should_process_conversation?(conversation)
      maybe_mark_as_open_if_skipped(conversation)
      return
    end

    method_name = __method__.to_s
    process_message_event(method_name, inbox.agent_bot, message, event)
  end

  def webwidget_triggered(event)
    contact_inbox = event.data[:contact_inbox]
    inbox = contact_inbox.inbox
    return unless should_process_event?(inbox)

    event_name = __method__.to_s
    payload = contact_inbox.webhook_data.merge(event: event_name)
    payload[:event_info] = event.data[:event_info]
    process_webhook_bot_event(inbox.agent_bot, payload)
  end

  private

  def should_process_conversation?(conversation)
    inbox = conversation.inbox
    return false unless connected_agent_bot_exist?(inbox)
    return false unless conversation.pending?

    return true unless inbox.offline_response?

    !within_working_hours?(inbox)
  end

  def should_process_event?(inbox)
    connected_agent_bot_exist?(inbox)
  end

  def connected_agent_bot_exist?(inbox)
    inbox.agent_bot_inbox&.active?
  end

  def within_working_hours?(inbox)
    current_time = Time.now.in_time_zone(inbox.timezone)
    day_of_week = current_time.wday

    working_hour = WorkingHour.find_by(inbox_id: inbox.id, day_of_week: day_of_week)
    return false unless working_hour
    return false if working_hour.closed_all_day
    return true if working_hour.open_all_day

    open_time = current_time.change(hour: working_hour.open_hour, min: working_hour.open_minutes)
    close_time = current_time.change(hour: working_hour.close_hour, min: working_hour.close_minutes)

    current_time.between?(open_time, close_time)
  end

  def process_message_event(method_name, agent_bot, message, _event)
    # Only webhook bots are supported
    payload = message.webhook_data.merge(event: method_name)
    process_webhook_bot_event(agent_bot, payload)
  end

  def process_webhook_bot_event(agent_bot, payload)
    return if agent_bot.outgoing_url.blank?

    AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload)
  end

  def process_csml_bot_event(event, agent_bot, message)
    AgentBots::CsmlJob.perform_later(event, agent_bot, message)
  end

  def maybe_mark_as_open_if_skipped(conversation)
    return unless conversation.pending?
    return if conversation.open?

    Rails.logger.info("[AgentBotListener] Conversación ##{conversation.id} no procesada por AgentBot. Marcando como 'open'.")
    conversation.update(status: 'open')
  end
end
