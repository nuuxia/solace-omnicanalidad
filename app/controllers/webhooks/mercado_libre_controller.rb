class Webhooks::MercadoLibreController < ActionController::API
  def process_payload
    Rails.logger.info("[Webhook] Payload recibido: #{params.to_unsafe_hash}")
    Webhooks::MercadoLibreEventsJob.perform_now(params.to_unsafe_hash)
    head :ok
  end
end
