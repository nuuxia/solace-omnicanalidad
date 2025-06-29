// app/javascript/dashboard/api/campaignsCsvWhatsapp.js
import ApiClient from './ApiClient';

// No se necesita importar 'API' ni 'axios'.
// Usaremos la variable global 'axios' que ya está disponible en el proyecto,
// al igual que lo hace la clase padre ApiClient.

class WhatsAppCSVCampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns_csv_whatsapp', { accountScoped: true });
  }

  // --- MÉTODO CORREGIDO ---
  // Llama a axios.get() directamente
  stats(id) {
    // this.url es provisto por la clase ApiClient y es correcto
    return axios.get(`${this.url}/${id}/stats`);
  }

  // --- MÉTODO CORREGIDO ---
  // Llama a axios.post() directamente
  retry(id) {
    return axios.post(`${this.url}/${id}/retry`, {});
  }

  downloadUrl(id, type) {
    const baseUrl = `${this.url}/${id}/download`;
    return type ? `${baseUrl}?type=${type}` : baseUrl;
  }
}

export default new WhatsAppCSVCampaignsAPI();