require 'openai'
class Integrations::Arrowai::ProcessorService
  pattr_initialize [:event_name!, :agent_bot!, :message!]

  def perform
    return if message.content.blank?

    conversation_starting
    make_client_call
  end

  private

  def make_client_call
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    client.add_headers("OpenAI-Beta" => "assistants=v1")

    conversation = @conversation
    @inbox = Inbox.find_by(id: conversation.inbox_id)
    assistant_id = @inbox.assistantid

    return create_messages({"type"=>"text", "text"=>{"value"=>"Assistant not found! Choose an assistant to talk with Software Clock AI!", "annotations"=>[]}}) if assistant_id.blank?

    conversation_thread_record = ConversationThreadRecord.find_by(conversation_id: conversation.id, assistant_id: assistant_id)

    if conversation_thread_record.present?
      thread_id =  conversation_thread_record.thread_id
    else  
      response = client.threads.create
      thread_id = response["id"]

      ConversationThreadRecord.create(conversation_id: conversation.id, assistant_id: assistant_id, thread_id: thread_id)
    end  

    message_id = client.messages.create(
      thread_id: thread_id,
      parameters: {
          role: "user",
          content: message.content
    })["id"]

    begin 
      run = client.runs.create(thread_id: thread_id,
      parameters: {
          assistant_id: assistant_id
      })
      run_id = run['id']

    rescue StandardError => e
      errorMessage = e.response[:body]["error"]["message"]
      return create_messages({"type"=>"text", "text"=>{"value"=> errorMessage, "annotations"=>[]}})
    end

    response = client.runs.retrieve(id: run_id, thread_id: thread_id)
    status = response['status']

    max_retries = 20  
    retry_count = 0

    while retry_count < max_retries do
      response = client.runs.retrieve(id: run_id, thread_id: thread_id)
      status = response['status']
  
      case status
      when 'queued', 'in_progress', 'cancelling'
          puts 'Sleeping'
          sleep 1 
      when 'completed'
          break 
      when 'requires_action'
          # Handle tool calls (see below)
      when 'cancelled', 'failed', 'expired'
          puts response['last_error'].inspect
          break # or `exit`
      else
          puts "Unknown status response: #{status}"
      end
    end

    return create_messages({"type"=>"text", "text"=>{"value"=>" Maximum retries reached! Exiting", "annotations"=>[]}}) if retry_count == max_retries

    messages = client.messages.list(thread_id: thread_id) 
    create_messages(messages["data"][0]["content"][0])
  end

  def create_messages(response)
    conversation = @conversation
    response_hash = response.is_a?(String) ? JSON.parse(response) : response
    conversation.messages.create!(
      {
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        content: response_hash["text"]["value"],
        sender: agent_bot,
        additional_attributes: response_hash
      }
    )
  end

  def conversation_starting
    @conversation ||= Conversation.find_by(id: message.conversation_id)
  end

end
