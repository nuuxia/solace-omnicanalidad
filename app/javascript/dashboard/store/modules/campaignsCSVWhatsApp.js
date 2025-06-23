// store/modules/campaignsWhatsapp.js
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

const processCampaignData = campaign => {
  if (!campaign) return null;
  try {
    if (campaign.template && typeof campaign.template === 'string') {
      campaign.template = JSON.parse(campaign.template);
    }
    return campaign;
  } catch (error) {
    return campaign;
  }
};

export const getters = {
  getUIFlags: _state => _state.uiFlags,
  getAllCampaigns: _state => {
    return _state.records.map(campaign => processCampaignData(campaign));
  },
  getCampaignsByType: _state => type => {
    return _state.records
      .filter(record => record.campaign_type === type)
      .map(campaign => processCampaignData(campaign));
  },
  isSyncing: _state => _state.uiFlags.isSyncing,
  isPreviewing: _state => _state.uiFlags.isPreviewing,
  previewError: _state => _state.uiFlags.previewError,
  syncError: _state => _state.uiFlags.syncError, // Opcional
};

export const actions = {
  async get({ commit }) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isFetching: true });
    try {
      const response = await WhatsAppCSVCampaignsAPI.get();
      const processedCampaigns = response.data.map(campaign =>
        processCampaignData(campaign)
      );
      commit(types.SET_WHATSAPP_CAMPAIGNS, processedCampaigns);
    } catch (error) {
      // Manejo de errores si es necesario
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isFetching: false });
    }
  },

  // AQUÍ EL CAMBIO IMPORTANTE:
  async create({ commit }, formData) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isCreating: true });
    try {
      // Enviamos directamente el FormData
      const response = await WhatsAppCSVCampaignsAPI.create(formData);
      const processedCampaign = processCampaignData(response.data);
      commit(types.ADD_WHATSAPP_CAMPAIGN, processedCampaign);
      return processedCampaign;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isCreating: false });
    }
  },

  async update({ commit }, { id, ...updateObj }) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isUpdating: true });
    try {
      const response = await WhatsAppCSVCampaignsAPI.update(id, {
        campaigns_whatsapp: updateObj,
      });
      const processedCampaign = processCampaignData(response.data);
      commit(types.EDIT_WHATSAPP_CAMPAIGN, processedCampaign);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isUpdating: false });
    }
  },

  async delete({ commit }, id) {
    commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isDeleting: true });
    try {
      await WhatsAppCSVCampaignsAPI.delete(id);
      commit(types.DELETE_WHATSAPP_CAMPAIGN, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_WHATSAPP_CAMPAIGN_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_WHATSAPP_CAMPAIGN_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_WHATSAPP_CAMPAIGNS](_state, data) {
    _state.records = data;
  },
  [types.ADD_WHATSAPP_CAMPAIGN](_state, data) {
    _state.records = [..._state.records, data];
  },
  [types.EDIT_WHATSAPP_CAMPAIGN](_state, data) {
    const index = _state.records.findIndex(record => record.id === data.id);
    if (index > -1) {
      _state.records = [
        ..._state.records.slice(0, index),
        data,
        ..._state.records.slice(index + 1),
      ];
    }
  },
  [types.DELETE_WHATSAPP_CAMPAIGN](_state, id) {
    _state.records = _state.records.filter(record => record.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
