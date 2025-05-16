require 'rails_helper'

RSpec.describe 'Webhooks::MercadoLibreController', type: :request do
  describe 'POST /webhooks/mercado_libre' do
    let(:valid_params) do
      {
        user_id: 123,
        topic: 'messages',
        resource: 'message_id',
        application_id: 'test_app_id'
      }
    end

    let(:processed_params) do
      {
        "user_id" => "123",
        "topic" => "messages",
        "resource" => "message_id",
        "application_id" => "test_app_id"
      }
    end

    it 'calls the MercadoLibreEventsJob with the processed params using perform_now' do
      allow(Webhooks::MercadoLibreEventsJob).to receive(:perform_now)
      expect(Webhooks::MercadoLibreEventsJob).to receive(:perform_now).with(processed_params)

      post '/webhooks/mercado_libre', params: valid_params
      expect(response).to have_http_status(:success)
    end
  end
end

class Webhooks::MercadoLibreController < ActionController::API
  def process_payload
    Webhooks::MercadoLibreEventsJob.perform_now(params.to_unsafe_h.except(:controller, :action))
    head :ok
  end
end
