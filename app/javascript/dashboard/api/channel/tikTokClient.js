/* global axios */
import ApiClient from '../ApiClient';
class TikTokClient extends ApiClient {
  constructor() {
    super('tik_tok', { accountScoped: true });
  }

  generateAuthorization() {
    return axios.post(`${this.url}/authorization`);
  }
}
export default new TikTokClient();
