// dashboard/api/WhatsAppCampaignsAPI.js
import ApiClient from './ApiClient';

class WhatsAppCampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns_whatsapp', { accountScoped: true });
  }
}

export default new WhatsAppCampaignsAPI();
