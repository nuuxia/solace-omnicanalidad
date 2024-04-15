class Integrations::Arrowai::ProcessorService
  pattr_initialize [:event_name!, :agent_bot!, :message!]

  def perform
    return if message.content.blank?

    conversation_starting
    make_client_call
  end

  private

  def make_client_call
    request = HTTParty.post(build_url, body: JSON(bot_payload), headers: headers)

    return if request.body.blank?

    response = JSON.parse(request.body)

    create_messages(response)
  end

  def create_messages(response)
    status = response['status']
    conversation = @conversation

    case status
    when 'success'
      response_text_messages(response, conversation)
    when 'error'
      response_error_messages(response, conversation)
    when 'fail'
      response_error_messages(response, conversation)
    end
  end

  def response_text_messages(message_payload, conversation)
    conversation.messages.create!(
      {
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        content: message_payload['message'],
        sender: agent_bot,
        additional_attributes: message_payload
      }
    )
  end

  def response_error_messages(message_payload, conversation)
    conversation.messages.create!(
      {
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        content: 'Something went wrong! Please try again.',
        sender: agent_bot,
        additional_attributes: message_payload
      }
    )
  end

  def response_fail_messages(message_payload, conversation)
    conversation.messages.create!(
      {
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        content: 'You are not autherized to chat with OpenAI! Agent will reponse soon. Please wait a minute...',
        sender: agent_bot,
        additional_attributes: message_payload
      }
    )
  end

  def bot_payload
    conversation = @conversation
    @inbox = Inbox.find_by(id: conversation.inbox_id)
    assistantId = @inbox.assistantid
    {
      'message': message.content,
      'assistant_id': assistantId
    }
  end

  def build_url
    "#{agent_bot.outgoing_url}"
  end

  def conversation_starting
    @conversation ||= Conversation.find_by(id: message.conversation_id)
  end

  def headers
    {
      'Content-Type' => 'application/json'
    }
  end
end
