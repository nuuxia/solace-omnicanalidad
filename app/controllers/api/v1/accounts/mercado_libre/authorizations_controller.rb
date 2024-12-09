class Api::V1::Accounts::MercadoLibre::AuthorizationsController < Api::V1::Accounts::BaseController
  include MercadoLibreConcern
  before_action :check_authorization
  def create
    code_verifier = generate_code_verifier
    session[:code_verifier] = code_verifier
    code_challenge = generate_code_challenge(code_verifier)
    auth_url = mercado_libre_auth_url(code_challenge)
    store_user_session_data
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
