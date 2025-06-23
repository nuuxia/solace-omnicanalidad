// dashboard/api/WhatsAppCampaignsAPI.js
import ApiClient from './ApiClient';

class WhatsAppCSVCampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns_csv_whatsapp', { accountScoped: true });
  }
}

export default new WhatsAppCSVCampaignsAPI();
