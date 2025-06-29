# frozen_string_literal: true

# Controller completo: gestiona campañas CSV‑WhatsApp (index, show, create,
# stats, retry, download, destroy) + helpers.
# Ruta POST  /campaigns_csv_whatsapp/:id/retry   → retry
# Ruta GET   /campaigns_csv_whatsapp/:id/stats   → stats
# Ruta GET   /campaigns_csv_whatsapp/:id/download → download(type)

class Api::V1::Accounts::CampaignsCsvWhatsappController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_campaign, only: %i[show destroy stats retry download]

  # ------------------------------------------------------------------
  # GET /api/v1/accounts/:account_id/campaigns_csv_whatsapp
  # ------------------------------------------------------------------
  def index
    campaigns = Current.account.campaigns_csv_whatsapp.includes(:inbox)
    render json: campaigns.as_json(include: :inbox)
  end

  # ------------------------------------------------------------------
  # GET /api/v1/accounts/:account_id/campaigns_csv_whatsapp/:id
  # ------------------------------------------------------------------
  def show
    render json: @campaign.as_json(include: :inbox)
  end

  # ------------------------------------------------------------------
  # POST /api/v1/accounts/:account_id/campaigns_csv_whatsapp
  # ------------------------------------------------------------------
  def create
    Rails.logger.info '[CsvWhatsapp#create] Creating CSV WhatsApp campaign…'

    csv_file = params[:csv_file]
    return render json: { errors: ['csv_file is required'] }, status: :unprocessable_entity if csv_file.blank?

    csv_url = Whatsapp::CampaignCsvWhatsappFileUploadService.new(csv_file).perform
    Rails.logger.info "✅ csv_original_url → #{csv_url}"

    permitted = params.permit(:title, :inbox_id, :scheduled_at, :template,
                              :body_variables, :button_variables,
                              :original_csv_filename)

    template    = safe_json(permitted[:template])
    body_vars   = json_list(permitted[:body_variables])
    button_vars = json_list(permitted[:button_variables])

    if params[:headerMediaFile].present?
      header_url = Whatsapp::CampaignWhatsappFileUploadService
                   .new(params[:headerMediaFile]).perform
      template['header_media_url'] = header_url
      Rails.logger.info "✅ header_media_url → #{header_url}"
    end

    campaign = Current.account.campaigns_csv_whatsapp.new(
      title: permitted[:title],
      inbox_id: permitted[:inbox_id],
      scheduled_at: permitted[:scheduled_at],
      template: template,
      body_variables: body_vars,
      button_variables: button_vars,
      csv_original_url: csv_url,
      original_csv_filename: permitted[:original_csv_filename] || csv_file.original_filename
    )

    if campaign.save
      enqueue_if_future(campaign)
      render json: campaign.as_json(include: :inbox), status: :created
    else
      Rails.logger.error "❌ Validation errors: #{campaign.errors.full_messages}"
      render json: { errors: campaign.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "❌ CSV campaign creation failed: #{e.message}\n#{e.backtrace.take(10).join("\n")}"
    render json: { errors: [e.message] }, status: :internal_server_error
  end

  # ------------------------------------------------------------------
  # GET /campaigns_csv_whatsapp/:id/stats
  # ------------------------------------------------------------------
  def stats
    render json: @campaign.progress_data.merge(campaign: @campaign)
  end

  # ------------------------------------------------------------------
  # POST /campaigns_csv_whatsapp/:id/retry
  # Re‑lanza sólo los números con status != sent
  # ------------------------------------------------------------------
  def retry
    unless @campaign.failed? || @campaign.completed?
      return render json: {
        errors: [I18n.t('campaign.retry.not_finished',
                        default: 'Campaign is still running')]
      }, status: :unprocessable_entity
    end

    service = Whatsapp::CampaignCsvWhatsappService.new(@campaign)
    pending = service.pending_rows

    if pending.empty?
      return render json: {
        message: I18n.t('campaign.retry.nothing_pending',
                        default: 'Nothing pending to retry')
      }, status: :ok
    end

    @campaign.update!(
      campaign_status: :scheduled,
      messages_total: pending.size,
      messages_sent: 0,
      messages_failed: 0
    )

    WhatsappCsvCampaignJob.perform_async(@campaign.id)
    render json: @campaign.as_json(include: :inbox), status: :accepted
  rescue StandardError => e
    Rails.logger.error "❌ Retry failed: #{e.message}"
    render json: { errors: [e.message] }, status: :internal_server_error
  end

  # ------------------------------------------------------------------
  # DELETE /campaigns_csv_whatsapp/:id
  # ------------------------------------------------------------------
  def destroy
    cleanup_scheduled_jobs(@campaign.id)
    @campaign.destroy!
    head :ok
  end

  # ------------------------------------------------------------------
  # GET /campaigns_csv_whatsapp/:id/download?type=sent|errors|all(nil)
  # ------------------------------------------------------------------
  def download
    url =
      case params[:type]
      when 'sent'   then @campaign.csv_sent_url
      when 'errors' then @campaign.csv_errors_url
      else @campaign.csv_original_url
      end

    return head :not_found if url.blank?

    redirect_to url
  end

  # ======================= helpers ==================================

  private

  def enqueue_if_future(campaign)
    return unless campaign.scheduled_at.present? && campaign.scheduled_at.future?

    delay = campaign.scheduled_at - Time.current
    WhatsappCsvCampaignJob.perform_in(delay, campaign.id)
    Rails.logger.info "⏰ Campaign #{campaign.id} scheduled in #{delay.round}s"
  end

  def set_campaign
    @campaign = Current.account.campaigns_csv_whatsapp.find(params[:id])
  end

  # ---------- JSON helpers ------------------------------------------
  def safe_json(str)
    return {} if str.blank?

    JSON.parse(str)
  rescue JSON::ParserError
    {}
  end

  def json_list(val)
    return [] if val.blank?

    val.is_a?(String) ? JSON.parse(val) : val
  rescue JSON::ParserError
    []
  end

  # ---------- Sidekiq cleanup ---------------------------------------
  def cleanup_scheduled_jobs(campaign_id)
    [Sidekiq::ScheduledSet.new, Sidekiq::RetrySet.new].each do |set|
      set
        .select { |j| %w[WhatsappCsvCampaignJob WhatsappCsvMessageJob].include?(j.klass) && j.args.first == campaign_id }
        .each(&:delete)
    end
  end
end
