# frozen_string_literal: true

require 'rails_helper'

describe MercadoLibre::IncomingMessageService, vcr: { record: :new_episodes } do
  let(:channel_mercado_libre) { create(:channel_mercado_libre) }
  let(:inbox) { create(:inbox, channel: channel_mercado_libre) }
  let(:params) { { "resource" => "cc209a115a0f430081b2f421ab096fff" } } # Dummy params for initialization

  describe '#initialize_client' do
    it 'initializes the MercadoLibre client with a valid access token' do
      VCR.use_cassette('mercado_libre/initialize_client') do
        service = described_class.new(inbox: inbox, params: params)
        client = service.send(:initialize_client)

        expect(client).to be_a(MercadoLibre::Client)
        expect(client).to be_valid
      end
    end
  end

  describe '#fetch_and_process_new_messages' do
    let(:service) { described_class.new(inbox: inbox, params: params) }
    let(:client_double) { instance_double(MercadoLibre::Client) }

    # Configuración para mockear el cliente de Mercado Libre
    before do
      allow(client_double).to receive(:fetch_new_messages).and_return(new_messages_response)
    end

    context 'when there are new messages' do
      let(:new_messages_response) do
        {
          "messages" => [
            {
              "id" => "msg_001",
              "text" => "Hello!",
              "from" => { "user_id" => "654321" },
              "to" => { "user_id" => "123456" },
              "message_resources" => [{ "name" => "packs", "id" => "pack_001" }]
            }
          ]
        }
      end

      before do
        allow(service).to receive(:message_from_channel_owner?).and_return(false)
        allow(service).to receive(:process_message)
      end

      it 'fetches and processes new messages' do
        service.send(:fetch_and_process_new_messages, client_double)

        expect(client_double).to have_received(:fetch_new_messages).with(params)
        expect(service).to have_received(:process_message).with(new_messages_response["messages"].first, client_double)
      end
    end

    context 'when messages are blank' do
      let(:new_messages_response) { { "messages" => [] } }

      it 'does not process any messages' do
        expect(service).not_to receive(:process_message)

        service.send(:fetch_and_process_new_messages, client_double)
      end
    end

    context 'when the message is from the channel owner' do
      let(:new_messages_response) do
        {
          "messages" => [
            {
              "id" => "msg_002",
              "text" => "Hello again!",
              "from" => { "user_id" => channel_mercado_libre.mercado_libre_user_id }, # Same as channel's user_id
              "to" => { "user_id" => "654321" }
            }
          ]
        }
      end

      before do
        allow(service).to receive(:message_from_channel_owner?).and_return(true)
      end

      it 'skips processing the message' do
        expect(service).not_to receive(:process_message)

        service.send(:fetch_and_process_new_messages, client_double)
      end
    end

    context 'when the message is not from the channel owner' do
      let(:new_messages_response) do
        {
          "messages" => [
            {
              "id" => "msg_003",
              "text" => "How are you?",
              "from" => { "user_id" => "654321" }, # Different from channel's user_id
              "to" => { "user_id" => channel_mercado_libre.mercado_libre_user_id }
            }
          ]
        }
      end

      before do
        allow(service).to receive(:process_message)
      end

      it 'processes the message' do
        service.send(:fetch_and_process_new_messages, client_double)

        expect(service).to have_received(:process_message).with(new_messages_response["messages"].first, client_double)
      end
    end
  end
end
