/* global axios */
import ApiClient from '../ApiClient';
class MercadoLibreClient extends ApiClient {
  constructor() {
    super('mercado_libre', { accountScoped: true });
  }

  generateAuthorization() {
    return axios.post(`${this.url}/authorization`);
  }
}
export default new MercadoLibreClient();
