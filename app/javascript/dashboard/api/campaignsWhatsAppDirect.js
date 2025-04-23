// dashboard/api/WhatsAppCampaignsAPI.js
import ApiClient from './ApiClient';

class WhatsAppCampaignsDirectAPI extends ApiClient {
  constructor() {
    super('campaigns_whatsapp/direct', { accountScoped: true });
  }
}

export default new WhatsAppCampaignsDirectAPI();
