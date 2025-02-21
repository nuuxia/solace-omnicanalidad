import ApiClient from './ApiClient';

class SyncWhatsAppTemplatesAPI extends ApiClient {
  constructor() {
    super('whatsapp/sync_whatsapp_templates', { accountScoped: true });
  }

  syncTemplates() {
    const accountId = this.accountIdFromRoute;
    if (!accountId) {
      throw new Error('Account ID is missing from route');
    }
    const endpoint = `${this.baseUrl()}/whatsapp/sync_whatsapp_templates`;
    return this.create({}, endpoint);
  }
}
export default new SyncWhatsAppTemplatesAPI();
