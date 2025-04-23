// dashboard/api/WhatsAppCampaignsAPI.js
import ApiClient from './ApiClient';

class WhatsAppCampaignDirectPreviewAPI extends ApiClient {
  constructor() {
    super('campaigns_whatsapp/direct/preview', { accountScoped: true });
  }
}

export default new WhatsAppCampaignDirectPreviewAPI();
