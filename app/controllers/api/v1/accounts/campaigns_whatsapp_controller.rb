# app/controllers/api/v1/accounts/campaigns_whatsapp_controller.rb
class Api::V1::Accounts::CampaignsWhatsappController < Api::V1::Accounts::BaseController
  before_action :set_campaign, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    Rails.logger.info "🔍 [CampaignsWhatsappController#index] Fetching campaigns for account ID=#{Current.account.id}"
    @campaigns = Current.account.campaigns_whatsapp.includes(:inbox)
    Rails.logger.info "📋 Found #{@campaigns.size} campaigns"
    render json: @campaigns.as_json(include: :inbox)
  end

  def show
    Rails.logger.info "👀 [CampaignsWhatsappController#show] Showing campaign ID=#{@campaign.id}"
    render json: @campaign.as_json(include: :inbox)
  end

  def create
    Rails.logger.info "📝 Creating new WhatsApp campaign..."
    # 1) Parametros base
    campaign_base = params.permit(
      :title,
      :enabled,
      :trigger_only_during_business_hours,
      :inbox_id,
      :sender_id,
      :scheduled_at,
      :campaign_status,
      :template
    ).to_h

    # 2) body_variables y button_variables (guardarlos "tal cual")
    raw_body_vars = params[:body_variables]
    raw_button_vars = params[:button_variables]

    body_vars = if raw_body_vars.is_a?(String)
                  JSON.parse(raw_body_vars) rescue []
                else
                  raw_body_vars || []
                end

    button_vars = if raw_button_vars.is_a?(String)
                    JSON.parse(raw_button_vars) rescue []
                  else
                    raw_button_vars || []
                  end

    # 3) Guardar template en formato JSON
    raw_template = campaign_base["template"]
    parsed_template = raw_template.present? ? JSON.parse(raw_template) : {}

    # 4) Subir headerMediaFile a S3 y guardar la URL en template["header_media_url"] (igual que en preview)
    if params[:headerMediaFile].present?
      begin
        Rails.logger.info "📂 Received headerMediaFile; uploading to S3..."
        header_url = Whatsapp::CampaignWhatsappFileUploadService.new(params[:headerMediaFile]).perform
        parsed_template["header_media_url"] = header_url
        Rails.logger.info "✅ Header media URL saved in template: #{header_url}"
      rescue => e
        Rails.logger.error "❌ Error uploading headerMediaFile: #{e.message}"
      end
    end

    # 5) Reemplazar en campaign_base
    campaign_base["template"] = parsed_template
    campaign_base["body_variables"] = body_vars
    campaign_base["button_variables"] = button_vars

    # 6) Procesar audiencia
    raw_audience = params.fetch(:audience, {})
    campaign_base["audience"] = parse_audience(raw_audience)

    @campaign = Current.account.campaigns_whatsapp.new(campaign_base)

    if @campaign.save
      Rails.logger.info "✅ Campaign created successfully, ID=#{@campaign.id}"
      schedule_campaign
      render json: @campaign.as_json(include: :inbox), status: :created
    else
      Rails.logger.error "❌ Campaign creation failed: #{@campaign.errors.full_messages}"
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    Rails.logger.error "❌ Parameter missing error: #{e.message}"
    render json: { errors: [e.message] }, status: :bad_request
  rescue => e
    Rails.logger.error "❌ Unexpected error during campaign creation: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { errors: ["An unexpected error occurred: #{e.message}"] }, status: :internal_server_error
  end

  def update
    Rails.logger.info "📝 [CampaignsWhatsappController#update] Updating campaign ID=#{@campaign.id}"
    campaign_params = params.permit(
      :title,
      :enabled,
      :trigger_only_during_business_hours,
      :inbox_id,
      :sender_id,
      :scheduled_at,
      :campaign_status,
      :template
    ).to_h

    raw_audience = params.require(:campaigns_whatsapp).fetch(:audience, {})
    campaign_params["audience"] = parse_audience(raw_audience)

    if @campaign.update(campaign_params)
      Rails.logger.info "✅ Campaign updated successfully"
      schedule_campaign if schedule_changed?(campaign_params)
      render json: @campaign.as_json(include: :inbox)
    else
      Rails.logger.error "❌ Update failed: #{@campaign.errors.full_messages}"
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    Rails.logger.error "❌ Parameter missing error during update: #{e.message}"
    render json: { errors: [e.message] }, status: :bad_request
  rescue => e
    Rails.logger.error "❌ Unexpected error during campaign update: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { errors: ["An unexpected error occurred: #{e.message}"] }, status: :internal_server_error
  end

  def destroy
    Rails.logger.info "🗑️ [CampaignsWhatsappController#destroy] Deleting campaign ID=#{@campaign.id}"
    cleanup_scheduled_jobs
    if @campaign.destroy
      Rails.logger.info "✅ Campaign and associated jobs deleted successfully"
      head :ok
    else
      Rails.logger.error "❌ Failed to delete campaign: #{@campaign.errors.full_messages}"
      render json: { errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "❌ Unexpected error during campaign deletion: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { errors: ["An unexpected error occurred: #{e.message}"] }, status: :internal_server_error
  end

  private

  def set_campaign
    Rails.logger.info "🔍 [CampaignsWhatsappController#set_campaign] Finding campaign ID=#{params[:id]}"
    @campaign = Current.account.campaigns_whatsapp.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ Campaign with ID=#{params[:id]} not found for account #{Current.account.id}"
    render json: { errors: ["Campaign not found"] }, status: :not_found
  end

  def parse_audience(aud_param)
    Rails.logger.debug "👀 [parse_audience] Starting parsing. Received aud_param: #{aud_param.inspect} (Class: #{aud_param.class})"
    return [] if aud_param.blank?

    items_to_process =
      if aud_param.is_a?(ActionController::Parameters)
        aud_param.keys.all? { |k| k.to_s =~ /^\d+$/ } ? aud_param.values : [aud_param]
      elsif aud_param.is_a?(Hash)
        aud_param.keys.all? { |k| k.to_s =~ /^\d+$/ } ? aud_param.values : [aud_param]
      elsif aud_param.is_a?(Array)
        aud_param
      else
        Rails.logger.warn "⚠️ [parse_audience] Unexpected audience format (Class: #{aud_param.class}). Returning empty."
        []
      end

    result = items_to_process.map do |item|
      param_item = item.is_a?(ActionController::Parameters) ? item : ActionController::Parameters.new(item)
      permitted_item = param_item.permit(:id, :type)
      permitted_item.to_h
    end.compact

    Rails.logger.debug "✅ [parse_audience] Final parsed result: #{result.inspect}"
    result
  end

  def schedule_campaign
    if @campaign.enabled? && @campaign.campaign_status == 'scheduled' && @campaign.scheduled_at&.future?
      delay = @campaign.scheduled_at - Time.current
      Rails.logger.info "⏰ Scheduling campaign ID=#{@campaign.id} for #{@campaign.scheduled_at} (in #{delay.round} seconds)"
      WhatsappCampaignJob.perform_in(delay, @campaign.id)
    elsif @campaign.enabled? && @campaign.campaign_status == 'scheduled' && @campaign.scheduled_at && @campaign.scheduled_at <= Time.current
      Rails.logger.info "🚀 Starting campaign ID=#{@campaign.id} immediately (scheduled_at is in the past)"
      WhatsappCampaignJob.perform_async(@campaign.id)
    else
      Rails.logger.info "ℹ️ Campaign ID=#{@campaign.id} will not be scheduled (enabled: #{@campaign.enabled?}, status: #{@campaign.campaign_status}, scheduled_at: #{@campaign.scheduled_at})"
    end
  end

  def cleanup_scheduled_jobs
    return unless @campaign&.id
    Rails.logger.info "🧹 Cleaning up scheduled jobs for campaign #{@campaign.id}"
    cleaned_count = 0
    scheduled_set = Sidekiq::ScheduledSet.new
    scheduled_set.each do |job|
      if job.klass == 'WhatsappCampaignJob' && job.args.first == @campaign.id
        Rails.logger.info "🗑️ Removing scheduled campaign job #{job.jid}"
        job.delete
        cleaned_count += 1
      elsif job.klass == 'WhatsappMessageJob' && job.args.first == @campaign.id
        Rails.logger.info "🗑️ Removing scheduled message job #{job.jid}"
        job.delete
        cleaned_count += 1
      end
    end
    retry_set = Sidekiq::RetrySet.new
    retry_set.each do |job|
      if (job.klass == 'WhatsappCampaignJob' || job.klass == 'WhatsappMessageJob') && job.args.first == @campaign.id
        Rails.logger.info "🗑️ Removing retry job #{job.jid} (klass: #{job.klass})"
        job.delete
        cleaned_count += 1
      end
    end
    Rails.logger.info "✅ Cleaned up #{cleaned_count} jobs from scheduled/retry sets for campaign #{@campaign.id}"
  end

  def schedule_changed?(new_params = {})
    current_scheduled_at = @campaign.scheduled_at
    current_status = @campaign.campaign_status
    current_enabled = @campaign.enabled
    new_scheduled_at = new_params["scheduled_at"]
    new_status = new_params["campaign_status"]
    new_enabled = new_params.key?("enabled") ? new_params["enabled"] : current_enabled

    changed = false
    if new_scheduled_at.present? && current_scheduled_at.present?
      changed ||= new_scheduled_at.to_i != current_scheduled_at.to_i
    elsif new_scheduled_at.present? != current_scheduled_at.present?
      changed = true
    end
    changed ||= new_status != current_status
    changed ||= new_enabled != current_enabled
    Rails.logger.debug "[schedule_changed?] Current(#{current_scheduled_at}, #{current_status}, #{current_enabled}) vs New(#{new_scheduled_at}, #{new_status}, #{new_enabled}) => Changed: #{changed}"
    changed
  end
end
