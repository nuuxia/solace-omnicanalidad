import { frontendURL } from '../../../../helper/URLHelper';

const campaigns = accountId => ({
  parentNav: 'campaigns',
  routes: [
    'campaigns_sms_index',
    'campaigns_livechat_index',
    'campaigns_whatsapp_index',
  ],
  menuItems: [
    {
      icon: 'arrow-swap',
      label: 'LIVE_CHAT',
      key: 'ongoingCampaigns',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/live_chat`),
      toStateName: 'campaigns_livechat_index',
    },
    {
      key: 'oneOffCampaigns',
      icon: 'sound-source',
      label: 'SMS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/sms`),
      toStateName: 'campaigns_sms_index',
    },
    {
      key: 'whatsappCampaigns',
      icon: 'whatsapp',
      label: 'WHATSAPP',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/whatsapp`),
      toStateName: 'campaigns_whatsapp_index',
    },
  ],
});

export default campaigns;
