<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';
import WhatsAppCampaignForm from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignForm.vue';
const emit = defineEmits(['close']);
const store = useStore();
const { t } = useI18n();
const isSyncButtonDisabled = ref(false);
// Cierra el diálogo
const handleClose = () => emit('close');
// Aquí despachamos al módulo `campaignsWhatsApp/create`
const addCampaign = async campaignDetails => {
  try {
    await store.dispatch(
      'campaignsWhatsApp/create',
      campaignDetails.campaigns_whatsapp
    );
    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.SUCCESS_MESSAGE'));
    handleClose();
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};
// El formulario emite `submit` con `campaignDetails`
const handleSubmit = campaignDetails => {
  // campaignDetails ya tiene la estructura correcta, pásalo directamente
  addCampaign(campaignDetails);
};
// Para sincronizar plantillas
const handleSyncTemplates = async () => {
  if (isSyncButtonDisabled.value) return;
  isSyncButtonDisabled.value = true;
  try {
    await store.dispatch('campaignsWhatsApp/syncTemplates');
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.SYNC.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.response?.message ||
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.SYNC.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    setTimeout(() => {
      isSyncButtonDisabled.value = false;
    }, 2000);
  }
};
</script>

<template>
  <div
    class="w-[400px] z-50 min-w-0 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] p-6 rounded-xl border border-slate-50 dark:border-slate-900 shadow-md flex flex-col gap-6"
  >
    <!-- Encabezado: Título a la izquierda, botón de sync a la derecha -->
    <div class="flex items-center justify-between">
      <h3 class="text-base font-medium text-slate-900 dark:text-slate-50">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.TITLE') }}
      </h3>
      <woot-button
        v-tooltip.right="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SYNC_BUTTON_TOOLTIP')"
        variant="text"
        color="slate"
        icon="arrow-clockwise"
        :disabled="isSyncButtonDisabled"
        @click="handleSyncTemplates"
      />
    </div>
    <!-- Formulario WhatsAppCampaignForm -->
    <WhatsAppCampaignForm @submit="handleSubmit" @cancel="handleClose" />
  </div>
</template>
