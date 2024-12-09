class Webhooks::MercadoLibreController < ActionController::API
  def process_payload
    Webhooks::MercadoLibreEventsJob.perform_now(params.to_unsafe_hash)
    head :ok
  end
end
