class Webhooks::TikTokController < ActionController::API
  def process_payload
    # we need to refrersh the token, and allow users to send and receive direct messages.
    Webhooks::TikTokEventsJob.perform_now(params.to_unsafe_hash)
    head :ok
  end
end
