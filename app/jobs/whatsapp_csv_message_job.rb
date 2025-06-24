class WhatsappCsvMessageJob
  include Sidekiq::Worker
  sidekiq_options queue: :whatsapp_csv_messages, retry: 3

  def perform(campaign_id, row_index)
    campaign = CampaignsCsvWhatsapp.find(campaign_id)
    service  = Whatsapp::CsvCampaignService.new(campaign)

    row = service.instance_variable_get(:@rows)[row_index]

    # expand placeholders → sólo demo, reemplaza por tu TemplatePlaceholderService
    expanded_template = campaign.template # falta expandir <{{1}}> etc.

    service.send_row(row, expanded_template)
    service.flush_csv! if (row_index % 25).zero? # cada 25 filas subimos progreso
  end
end
