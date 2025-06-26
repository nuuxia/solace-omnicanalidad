// store/modules/campaignsCSVWhatsapp.js
import WhatsAppCSVCampaignsAPI from '../../api/campaignsCSVWhatsApp';
import types from '../mutation-types';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isSyncing: false,
    isPreviewing: false,
    previewError: null,
    syncError: null,
  },
};

const parseTemplate = campaign => {
  if (!campaign) return null;
  try {
    if (campaign.template && typeof campaign.template === 'string') {
      campaign.template = JSON.parse(campaign.template);
    }
  } catch (_) {
    /* ignore */
  }
  return campaign;
};

export const getters = {
  getUIFlags: s => s.uiFlags,
  isSyncing: s => s.uiFlags.isSyncing,
  isPreviewing: s => s.uiFlags.isPreviewing,
  previewError: s => s.uiFlags.previewError,
  syncError: s => s.uiFlags.syncError,
  getAllCampaigns: s => s.records.map(parseTemplate),
  getCampaignsByType: s => type =>
    s.records.filter(r => r.campaign_type === type).map(parseTemplate),
};

export const actions = {
  // ─────────── CRUD ───────────
  async get({ commit }) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isFetching: true });
    try {
      const { data } = await WhatsAppCSVCampaignsAPI.get();
      commit(types.SET_WHATSAPP_CAMPAIGNS, data.map(parseTemplate));
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isFetching: false });
    }
  },

  async create({ commit }, formData) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isCreating: true });
    try {
      const { data } = await WhatsAppCSVCampaignsAPI.create(formData);
      commit(types.ADD_WHATSAPP_CAMPAIGN, parseTemplate(data));
      return data;
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isCreating: false });
    }
  },

  async update({ commit }, { id, ...payload }) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isUpdating: true });
    try {
      const { data } = await WhatsAppCSVCampaignsAPI.update(id, payload);
      commit(types.EDIT_WHATSAPP_CAMPAIGN, parseTemplate(data));
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isUpdating: false });
    }
  },

  async delete({ commit }, id) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isDeleting: true });
    try {
      await WhatsAppCSVCampaignsAPI.delete(id);
      commit(types.DELETE_WHATSAPP_CAMPAIGN, id);
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isDeleting: false });
    }
  },

  // ─────────── NUEVO: stats / retry / download ───────────
  stats(_, id) {
    return WhatsAppCSVCampaignsAPI.stats(id).then(r => r.data);
  },
  retry(_, id) {
    return WhatsAppCSVCampaignsAPI.retry(id);
  },
  download(_, { id, type }) {
    // redirigimos para forzar la descarga
    window.location = WhatsAppCSVCampaignsAPI.downloadUrl(id, type);
  },
};

export const mutations = {
  [types.SET_WHATSAPP_CAMPAIGN_UI_FLAG](s, data) {
    s.uiFlags = { ...s.uiFlags, ...data };
  },
  [types.SET_WHATSAPP_CAMPAIGNS](s, data) {
    s.records = data;
  },
  [types.ADD_WHATSAPP_CAMPAIGN](s, data) {
    s.records = [...s.records, data];
  },
  [types.EDIT_WHATSAPP_CAMPAIGN](s, data) {
    const i = s.records.findIndex(r => r.id === data.id);
    if (i > -1) s.records.splice(i, 1, data);
  },
  [types.DELETE_WHATSAPP_CAMPAIGN](s, id) {
    s.records = s.records.filter(r => r.id !== id);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
