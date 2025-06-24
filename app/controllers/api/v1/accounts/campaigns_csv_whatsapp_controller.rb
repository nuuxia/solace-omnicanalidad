class Api::V1::Accounts::CampaignsCsvWhatsappController < Api::V1::Accounts::BaseController
  before_action :set_campaign, only: %i[show update destroy]
  before_action :check_authorization

  def index
    campaigns = Current.account.campaigns_csv_whatsapp.includes(:inbox)
    render json: campaigns.as_json(include: :inbox)
  end

  def show
    render json: @campaign.as_json(include: :inbox)
  end

  def create
    ActiveRecord::Base.transaction do
      @campaign = Current.account.campaigns_csv_whatsapp.new(campaign_params)

      # CSV subido
      if params[:contacts_file].present?
        @campaign.csv_file.attach(params[:contacts_file])
        rows = ::CSV.read(params[:contacts_file].path, headers: true)
        @campaign.messages_total = rows.count
      end

      if @campaign.save
        @campaign.kickoff!
        render json: @campaign.as_json(include: :inbox), status: :created
      else
        render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def update
    if @campaign.update(campaign_params)
      render json: @campaign.as_json(include: :inbox)
    else
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  private

  def set_campaign
    @campaign = Current.account.campaigns_csv_whatsapp.find(params[:id])
  end

  def campaign_params
    params.permit(
      :title, :inbox_id, :scheduled_at, :enabled,
      :template, :body_variables, :button_variables
    )
  end
end
