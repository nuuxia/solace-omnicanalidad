<script setup>
/**
 * Página principal donde se listan, crean y gestionan campañas
 * CSV-WhatsApp.
 *
 * – Muestra el listado
 * – Abre diálogo “Nueva campaña”
 * – Abre diálogo “Estadísticas / Re-intentar”
 * – Confirma eliminación
 */

import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';

import WhatsAppCSVCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/WhatsAppCSVCampaignDialog.vue';

import WhatsAppCSVCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';

import ConfirmDeleteCampaignWhatsappCSVPDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/ConfirmDeleteWhatsAppCSVCampaignDialog.vue';

import WhatsAppCSVCampaignStatsDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/WhatsAppCSVCampaignStatsDialog.vue'; // 📊 diálogo stats

/* ------------------------------------------------------------------ */
/* refs & store                                                       */
/* ------------------------------------------------------------------ */

const store = useStore();
const { t } = useI18n();

/* diálogos --------------------------------------------------------- */

const showWhatsAppCampaignDialog = ref(false);
const showStatsDialog = ref(false);

const confirmDeleteCampaignDialogRef = ref(null);
const selectedCampaignToDelete = ref(null);
const selectedCampaignForStats = ref(null);

/* cargar campañas una sola vez al montar -------------------------- */

store.dispatch('campaignsCSVWhatsApp/get');

/* ui flags --------------------------------------------------------- */

const isFetching = computed(
  () => store.state.campaignsCSVWhatsApp.uiFlags.isFetching
);

const whatsappCampaigns = computed(
  () => store.state.campaignsCSVWhatsApp.records
);

const hasNoCampaigns = computed(() => !whatsappCampaigns.value?.length);

/* handlers --------------------------------------------------------- */

const openNewDialog = () => (showWhatsAppCampaignDialog.value = true);
const closeNewDialog = () => (showWhatsAppCampaignDialog.value = false);

const handleDelete = campaign => {
  selectedCampaignToDelete.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};

const handleStats = campaign => {
  selectedCampaignForStats.value = campaign;
  showStatsDialog.value = true;
};

const closeStatsDialog = () => {
  showStatsDialog.value = false;
  selectedCampaignForStats.value = null;
  // refrescamos la lista por si cambió algo
  store.dispatch('campaignsCSVWhatsApp/get');
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.CSV.WHATSAPP.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.CSV.WHATSAPP.NEW_CAMPAIGN')"
    @click="openNewDialog"
  >
    <!-- diálogo “Nueva campaña” -->
    <template #action>
      <WhatsAppCSVCampaignDialog
        v-if="showWhatsAppCampaignDialog"
        @close="closeNewDialog"
      />
    </template>

    <!-- loading / listado / empty-state -->
    <div v-if="isFetching" class="flex items-center justify-center py-10" />

    <!-- 📊 se añadió el evento @stats -->
    <CampaignList
      v-else-if="!hasNoCampaigns"
      :campaigns="whatsappCampaigns"
      enable-stats
      @delete="handleDelete"
      @stats="handleStats"
    />

    <WhatsAppCSVCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />

    <!-- confirmación de borrado -->
    <ConfirmDeleteCampaignWhatsappCSVPDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaignToDelete"
    />

    <!-- estadísticas / re-intento / descargas -->
    <WhatsAppCSVCampaignStatsDialog
      v-if="showStatsDialog && selectedCampaignForStats"
      :campaign="selectedCampaignForStats"
      @close="closeStatsDialog"
    />
  </CampaignLayout>
</template>
