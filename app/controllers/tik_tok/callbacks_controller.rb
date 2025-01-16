# app/controllers/tik_tok/callbacks_controller.rb
class TikTok::CallbacksController < ApplicationController
  include TikTokConcern

  def show
    response_data = ensure_access_token
    return redirect_to tik_tok_app_redirect_url unless response_data

    code = response_data[:code]
    code_verifier = response_data[:code_verifier]

    ActiveRecord::Base.transaction do
      token_data = TikTok::TokenService.new(code, code_verifier).call
      inbox = create_inbox(token_data)
      redirect_to app_tik_tok_inbox_agents_url(account_id: account.id, inbox_id: inbox.id)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    redirect_to tik_tok_app_redirect_url
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

  def tik_tok_app_redirect_url
    app_new_tik_tok_inbox_url(account_id: account.id)
  end

  def create_inbox(token_data)
    inbox = create_tik_tok_channel_with_inbox(token_data)
    inbox
  end

  def create_tik_tok_channel_with_inbox(token_data)
    ActiveRecord::Base.transaction do
      channel_tik_tok = Channel::TikTok.create!(
        account: account,
        tik_tok_access_token: token_data['access_token'],
        tik_tok_refresh_token: token_data['refresh_token'],
        tik_tok_user_id: token_data['open_id'],
        tik_tok_token_expires_at: Time.current + token_data['expires_in'],
        tok_tok_refresh_expires_at: Time.current + token_data['expires_in']
      )
      inbox = account.inboxes.create!(
        account: account,
        channel: channel_tik_tok,
        name: 'Tik Tok'
      )
      inbox
    end
  end

  def permitted_params
    params.permit(:code)
  end
end
