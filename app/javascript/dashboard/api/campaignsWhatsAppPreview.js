// api/WhatsAppCampaignsPreviewAPI.js
import ApiClient from './ApiClient';
class WhatsAppCampaignsPreviewAPI extends ApiClient {
  constructor() {
    super('campaigns_whatsapp/preview', { accountScoped: true });
  }

  preview(previewData) {
    return this.create(previewData, this.url);
  }
}
export default new WhatsAppCampaignsPreviewAPI();
