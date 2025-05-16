class MercadoLibre::UsersController < ApplicationController
  def get_user_info
    inbox = Inbox.find_by(id: params[:inbox_id])

    if inbox.nil?
      return render json: { success: false, error: 'Inbox no encontrado' }, status: :not_found
    end

    user_info = MercadoLibre::GetUserInfoService.new(inbox: inbox).perform

    if user_info
      render json: { success: true, data: user_info }, status: :ok
    else
      render json: { success: false, error: 'No se pudo obtener la información del usuario' }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end
end
