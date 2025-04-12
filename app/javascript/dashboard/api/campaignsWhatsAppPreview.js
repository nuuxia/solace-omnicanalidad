// api/campaignsWhatsAppPreview.js
import ApiClient from './ApiClient';

class WhatsAppCampaignsPreviewAPI extends ApiClient {
  constructor() {
    // Define el recurso y que la URL sea accountScoped para que se incluya el accountId
    super('campaigns_whatsapp/preview', { accountScoped: true });
  }

  preview(previewData) {
    // previewData = { inboxId, phoneNumber, template, headerMediaFile, bodyVariables, buttonVariables }
    const formData = new FormData();

    // 1. Archivo (si existe)
    if (previewData.headerMediaFile) {
      formData.append('headerMediaFile', previewData.headerMediaFile);
    }

    // 2. Inbox ID
    formData.append('inbox_id', previewData.inboxId);

    // 3. Número de teléfono
    formData.append('phone_number', previewData.phoneNumber);

    // 4. Template (como string JSON)
    formData.append('template', JSON.stringify(previewData.template));

    // 5. Body Variables (si existen)
    if (previewData.bodyVariables) {
      formData.append(
        'body_variables',
        JSON.stringify(previewData.bodyVariables)
      );
    }

    // 6. Button Variables (si existen)
    if (previewData.buttonVariables) {
      formData.append(
        'button_variables',
        JSON.stringify(previewData.buttonVariables)
      );
    }

    // Envía el FormData mediante el método create del ApiClient
    return this.create(formData);
  }
}

export default new WhatsAppCampaignsPreviewAPI();