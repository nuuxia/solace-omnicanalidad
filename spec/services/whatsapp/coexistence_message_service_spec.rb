require 'rails_helper'

describe Whatsapp::CoexistenceMessageService do
  describe '#perform' do
    before do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
    end

    let!(:whatsapp_channel) { create(:channel_whatsapp, sync_templates: false) }
    let(:channel_phone_number) { whatsapp_channel.phone_number.delete('+') }
    let!(:params) do
      {
        'entry' => [{
          'changes' => [{
            'value' => {
              'contacts' => [{ 'profile' => { 'name' => 'John Doe' }, 'wa_id' => '9876543210' }],
              'messages' => [{
                'from' => channel_phone_number, # Sender is the same as channel's phone number (coexistent device)
                'to' => '9876543210', # Recipient is the contact
                'id' => 'wamid.SDFADSf23sfasdafasdfa',
                'text' => { 'body' => 'Hello from coexistent device' },
                'timestamp' => '1633034394',
                'type' => 'text'
              }]
            }
          }]
        }]
      }.with_indifferent_access
    end

    context 'when valid message from coexistent device' do
      it 'creates appropriate conversations, message and contacts' do
        described_class.new(inbox: whatsapp_channel.inbox, params: params).perform
        expect(whatsapp_channel.inbox.conversations.count).not_to eq(0)
        expect(Contact.all.first.name).to eq('John Doe')

        # Message should be created as outgoing since it was sent from a coexistent device
        message = whatsapp_channel.inbox.messages.first
        expect(message.content).to eq('Hello from coexistent device')
        expect(message.message_type).to eq('outgoing')
      end

      it 'appends to last conversation when conversation already exists' do
        contact_inbox = create(:contact_inbox, inbox: whatsapp_channel.inbox,
                                               source_id: params[:entry].first[:changes].first[:value][:messages].first[:to])
        2.times.each { create(:conversation, inbox: whatsapp_channel.inbox, contact_inbox: contact_inbox) }
        last_conversation = create(:conversation, inbox: whatsapp_channel.inbox, contact_inbox: contact_inbox)

        described_class.new(inbox: whatsapp_channel.inbox, params: params).perform

        # no new conversation should be created
        expect(whatsapp_channel.inbox.conversations.count).to eq(3)

        # message appended to the last conversation
        message = last_conversation.messages.last
        expect(message.content).to eq('Hello from coexistent device')
        expect(message.message_type).to eq('outgoing')
      end
    end

    context 'when message is not from coexistent device' do
      let!(:non_coexistent_params) do
        {
          'entry' => [{
            'changes' => [{
              'value' => {
                'contacts' => [{ 'profile' => { 'name' => 'John Doe' }, 'wa_id' => '9876543210' }],
                'messages' => [{
                  'from' => '9876543210', # Different from channel's phone number
                  'id' => 'wamid.SDFADSf23sfasdafasdfa',
                  'text' => { 'body' => 'Hello from contact' },
                  'timestamp' => '1633034394',
                  'type' => 'text'
                }]
              }
            }]
          }]
        }.with_indifferent_access
      end

      it 'does not process the message' do
        expect_any_instance_of(described_class).to receive(:from_coexistent_device?).and_return(false)
        expect_any_instance_of(described_class).not_to receive(:process_coexistent_message)

        described_class.new(inbox: whatsapp_channel.inbox, params: non_coexistent_params).perform
      end
    end
  end
end
