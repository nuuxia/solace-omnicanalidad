# app/controllers/mercado_libre/callbacks_controller.rb
class MercadoLibre::CallbacksController < ApplicationController
  include MercadoLibreConcern

  def show
    response_data = ensure_access_token
    return redirect_to mercado_libre_app_redirect_url unless response_data

    code = response_data[:code]
    code_verifier = response_data[:code_verifier]

    ActiveRecord::Base.transaction do
      token_data = MercadoLibre::TokenService.new(code, code_verifier).call
      inbox = create_inbox(token_data)
      redirect_to app_mercado_libre_inbox_agents_url(account_id: account.id, inbox_id: inbox.id)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    redirect_to mercado_libre_app_redirect_url
  end

  private

  def account_id
    session[:account_id]
  end

  def account
    @account ||= Account.find(account_id)
  end

  def ensure_access_token
    code = permitted_params[:code]
    code_verifier = session[:code_verifier]

    if code.blank?
      raise StandardError, "Authorization code is not present"
    end

    { code: code, code_verifier: code_verifier }
  end

  def mercado_libre_app_redirect_url
    app_new_mercado_libre_inbox_url(account_id: account.id)
  end

  def create_inbox(token_data)
    inbox = create_mercado_libre_channel_with_inbox(token_data)
    inbox
  end

  def create_mercado_libre_channel_with_inbox(token_data)
    ActiveRecord::Base.transaction do
      channel_mercado_libre = Channel::MercadoLibre.create!(
        account: account,
        mercado_libre_access_token: token_data['access_token'],
        mercado_libre_refresh_token: token_data['refresh_token'],
        mercado_libre_user_id: token_data['user_id'],
        mercado_libre_token_expires_at: Time.current + token_data['expires_in']
      )

      inbox = account.inboxes.create!(
        account: account,
        channel: channel_mercado_libre,
        name: 'Mercado Libre'
      )

      inbox
    end
  end

  def permitted_params
    params.permit(:code)
  end
end
