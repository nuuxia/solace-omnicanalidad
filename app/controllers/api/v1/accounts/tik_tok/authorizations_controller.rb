class Api::V1::Accounts::TikTok::AuthorizationsController < Api::V1::Accounts::BaseController
  include TikTokConcern
  before_action :check_authorization

  def create
    # generate CSRF state
    code_verifier = generate_code_verifier
    session[:code_verifier] = code_verifier
    csrf_state = generate_csrf_state
    store_user_session_data
    # save the state in a cookie
    cookies[:csrf_state] = { value: csrf_state, expires: 10.minutes.from_now, httponly: true }

    # build auth url
    auth_url = build_tiktok_auth_url(csrf_state)

    # render auth_url
    render json: { authUrl: auth_url }, status: :ok
  end

  private

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def store_user_session_data
    session[:account_id] = Current.account.id
  end
end
