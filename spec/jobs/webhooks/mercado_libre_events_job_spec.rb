require 'rails_helper'

RSpec.describe Webhooks::MercadoLibreEventsJob, type: :job do
  subject(:job) { described_class.perform_later(params) }

  let!(:account) { create(:account) } # Creación de la cuenta
  let!(:mercado_libre_channel) do
    create(
      :channel_mercado_libre,
      account: account,
      mercado_libre_user_id: '123',
      mercado_libre_access_token: 'access_token',
      mercado_libre_refresh_token: 'refresh_token',
      mercado_libre_token_expires_at: 1.hour.from_now
    )
  end

  let!(:params) do
    {
      'user_id' => '123',
      'application_id' => ENV['MERCADO_LIBRE_APP_ID'],
      'topic' => 'messages',
      'resource' => 'resource_1'
    }
  end

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(params)
      .on_queue('default')
  end

  context 'when invalid params' do
    it 'returns nil when no user_id' do
      expect(described_class.perform_now({})).to be_nil
    end

    it 'returns nil when no matching channel is found' do
      expect(described_class.perform_now({ 'user_id' => '999' })).to be_nil
    end
  end

  context 'when valid params' do
    it 'calls MercadoLibre::IncomingMessageService' do
      process_service = double
      allow(MercadoLibre::IncomingMessageService).to receive(:new).and_return(process_service)
      allow(process_service).to receive(:perform)

      expect(MercadoLibre::IncomingMessageService).to receive(:new).with(
        inbox: mercado_libre_channel.inbox,
        params: params
      )
      expect(process_service).to receive(:perform)

      described_class.perform_now(params)
    end
  end

  context 'when the message has already been processed' do
    before do
      create(:message, source_id: 'resource_1')
    end

    it 'does not call MercadoLibre::IncomingMessageService' do
      expect(MercadoLibre::IncomingMessageService).not_to receive(:new)
      described_class.perform_now(params)
    end
  end

  context 'when the application_id is invalid' do
    before do
      params['application_id'] = 'invalid_id'
    end

    it 'logs an error' do
      expect(Rails.logger).to receive(:error).with(/Webhook application_id does not match the expected value/)
      described_class.perform_now(params)
    end
  end
end
