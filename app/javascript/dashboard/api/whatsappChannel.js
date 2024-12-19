import ApiClient from './ApiClient';

class WhatsappChannel extends ApiClient {
  constructor() {
    super('channels/automated_whatsapp_embedded_signup', {
      accountScoped: true,
    });
  }

  automatedSignup(data) {
    return this.create({ automated_whatsapp_embedded_signup: data });
  }
}

export default new WhatsappChannel();
