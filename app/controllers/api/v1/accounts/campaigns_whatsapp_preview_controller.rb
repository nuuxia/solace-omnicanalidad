class Api::V1::Accounts::CampaignsWhatsappPreviewController < Api::V1::Accounts::BaseController
  def create
    # Extraemos los parámetros enviados desde el FE
    inbox_id          = params[:inbox_id]
    phone_number      = params[:phone_number]
    template_json     = params[:template]
    header_media_file = params[:headerMediaFile]
    body_variables    = params[:body_variables] || []
    button_variables  = params[:button_variables] || []

    # Parseamos el JSON del template si está presente
    template = template_json.present? ? JSON.parse(template_json) : {}

    preview_service = Whatsapp::CampaignWhatsappPreviewService.new(
      account: Current.account,
      inbox_id: inbox_id,
      phone_number: phone_number,
      template: template,
      header_media_file: header_media_file,
      body_variables: body_variables,
      button_variables: button_variables
    )

    result = preview_service.perform
    render json: { success: true, result: result }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Preview Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
