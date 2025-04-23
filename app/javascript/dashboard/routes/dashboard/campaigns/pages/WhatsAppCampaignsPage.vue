<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';

import WhatsAppCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppCampaignDialog.vue';
import WhatsAppCampaignDirectDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/Direct/WhatsAppCampaignDirectDialog.vue';

import WhatsAppCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';
import ConfirmDeleteCampaignWhatsappDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/ConfirmDeleteWhatsAppCampaignDialog.vue';

const store = useStore();
const { t } = useI18n();

/* ───────────────────────── dialogs ───────────────────────── */
const showCampaignDialog = ref(false); // normal
const showDirectCampaignDialog = ref(false); // direct

/* ───────────────────────── delete dialog ─────────────────── */
const confirmDeleteCampaignDialogRef = ref(null);
const selectedCampaign = ref(null);

/* ───────────────────────── fetch campaigns ───────────────── */
onMounted(() => {
  store.dispatch('campaignsWhatsApp/get');
});

const isFetching = computed(
  () => store.state.campaignsWhatsApp.uiFlags.isFetching
);
const whatsappCampaigns = computed(() => store.state.campaignsWhatsApp.records);
const hasNoCampaigns = computed(() => !whatsappCampaigns.value?.length);

function toggleCampaignDialog() {
  if (showDirectCampaignDialog.value) showDirectCampaignDialog.value = false;
  showCampaignDialog.value = !showCampaignDialog.value;
}

function toggleDirectCampaignDialog() {
  if (showCampaignDialog.value) showCampaignDialog.value = false;
  showDirectCampaignDialog.value = !showDirectCampaignDialog.value;
}

function closeCampaignDialog() {
  showCampaignDialog.value = false;
}

function closeDirectCampaignDialog() {
  showDirectCampaignDialog.value = false;
}

function handleDelete(campaign) {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
}
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.WHATSAPP.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.WHATSAPP.NEW_CAMPAIGN')"
    :second-button-label="t('CAMPAIGN.WHATSAPP.NEW_DIRECT_CAMPAIGN')"
    @click="toggleCampaignDialog"
    @second-click="toggleDirectCampaignDialog"
  >
    <!-- diálogos montados en el slot action -->
    <template #action>
      <WhatsAppCampaignDialog
        v-if="showCampaignDialog"
        @close="closeCampaignDialog"
      />
      <WhatsAppCampaignDirectDialog
        v-if="showDirectCampaignDialog"
        @close="closeDirectCampaignDialog"
      />
    </template>

    <!-- contenido principal -->
    <div v-if="isFetching" class="flex items-center justify-center py-10" />

    <CampaignList
      v-else-if="!hasNoCampaigns"
      :campaigns="whatsappCampaigns"
      @delete="handleDelete"
    />

    <WhatsAppCampaignEmptyState
      v-else
      :title="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.TITLE')"
      :subtitle="t('CAMPAIGN.WHATSAPP.EMPTY_STATE.SUBTITLE')"
      class="pt-14"
    />

    <ConfirmDeleteCampaignWhatsappDialog
      ref="confirmDeleteCampaignDialogRef"
      :selected-campaign="selectedCampaign"
    />
  </CampaignLayout>
</template>
