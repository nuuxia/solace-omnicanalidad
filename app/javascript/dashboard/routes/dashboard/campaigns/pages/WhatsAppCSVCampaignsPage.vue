<script setup>
/**
 * Página principal donde se listan, crean y gestionan campañas CSV-WhatsApp.
 */
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import metaIcon from '../../../../../../../public/assets/images/meta/meta_icon.webp';

import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';

import WhatsAppCSVCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/WhatsAppCSVCampaignDialog.vue';

import WhatsAppCSVCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';

import ConfirmDeleteCampaignWhatsappCSVPDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/ConfirmDeleteWhatsAppCSVCampaignDialog.vue';

import WhatsAppCSVCampaignStatsDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/WhatsAppCSVCampaignStatsDialog.vue';

import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t } = useI18n();

/* dialogs & selection */
const showWhatsAppCampaignDialog = ref(false);
const showStatsDialog = ref(false);
const confirmDeleteCampaignDialogRef = ref(null);
const selectedCampaignToDelete = ref(null);
const selectedCampaignForStats = ref(null);

/* initial fetch */
store.dispatch('campaignsCSVWhatsApp/get');

/* ui flags */
const isFetching = computed(
  () => store.state.campaignsCSVWhatsApp.uiFlags.isFetching
);
const whatsappCampaigns = computed(
  () => store.state.campaignsCSVWhatsApp.records
);
const hasNoCampaigns = computed(() => !whatsappCampaigns.value?.length);

/* ─────────── Sync plantillas Meta ─────────── */
const isSyncDisabled = ref(false);

const handleSync = async () => {
  if (isSyncDisabled.value) return;
  isSyncDisabled.value = true;
  try {
    await store.dispatch('campaignsWhatsApp/syncTemplates');
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.SYNC.SUCCESS'));
  } catch {
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.SYNC.ERROR'));
  } finally {
    setTimeout(() => (isSyncDisabled.value = false), 2000);
  }
};

/* dialog helpers */
const openNewDialog = () => (showWhatsAppCampaignDialog.value = true);
const closeNewDialog = () => (showWhatsAppCampaignDialog.value = false);

/* delete / stats */
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
  store.dispatch('campaignsCSVWhatsApp/get');
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.CSV.WHATSAPP.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.CSV.WHATSAPP.NEW_CAMPAIGN')"
    @click="openNewDialog"
  >
    <!-- BOTONES ADICIONALES A LA DERECHA DEL BOTÓN PRINCIPAL -->
    <template #action>
      <div class="flex items-center">
        <Button
          variant="solid"
          size="sm"
          icon="i-lucide-rotate-ccw"
          class="bg-woot-500 mr-2 flex-none"
          :disabled="isSyncDisabled"
          @click="handleSync"
        >
          {{ t('CAMPAIGN.CSV.WHATSAPP.SYNC.LABEL') }}
        </Button>
        <a
          href="https://business.facebook.com/latest/whatsapp_manager/message_templates"
          target="_blank"
          rel="noopener noreferrer"
          :title="t('CAMPAIGN.CSV.WHATSAPP.META_TEMPLATES_HINT')"
          class="flex items-center ml-2"
        >
          <img :src="metaIcon" alt="Meta Icon" class="h-6 w-6" />
        </a>
      </div>
    </template>

    <!-- CONTENIDO PRINCIPAL DE TU PÁGINA -->
    <div v-if="isFetching" class="flex items-center justify-center py-10" />

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

    <ConfirmDeleteCampaignWhatsappCSVPDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaignToDelete"
    />

    <WhatsAppCSVCampaignDialog
      v-if="showWhatsAppCampaignDialog"
      @close="closeNewDialog"
    />

    <WhatsAppCSVCampaignStatsDialog
      v-if="showStatsDialog && selectedCampaignForStats"
      :campaign="selectedCampaignForStats"
      @close="closeStatsDialog"
    />
  </CampaignLayout>
</template>
