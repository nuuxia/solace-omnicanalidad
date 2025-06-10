<script setup>
import { computed, ref, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';

import CampaignLayout from 'dashboard/components-next/Campaigns/CampaignLayout.vue';
import CampaignList from 'dashboard/components-next/Campaigns/Pages/CampaignPage/CampaignList.vue';
import WhatsAppCSVCampaignDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/WhatsAppCSVCampaignDialog.vue';
import WhatsAppCSVCampaignEmptyState from 'dashboard/components-next/Campaigns/EmptyState/WhatsAppCampaignEmptyState.vue';
import ConfirmDeleteCampaignWhatsappCSVPDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCSVCampaign/ConfirmDeleteWhatsAppCSVCampaignDialog.vue';

const store = useStore();
const { t } = useI18n();

const showWhatsAppCampaignDialog = ref(false);
const confirmDeleteCampaignDialogRef = ref(null);
const selectedCampaign = ref(null);

onMounted(() => {
  store.dispatch('campaignsWhatsApp/get');
});

const isFetching = computed(
  () => store.state.campaignsWhatsApp.uiFlags.isFetching
);

const whatsappCampaigns = computed(() => {
  const campaigns = store.state.campaignsWhatsApp.records;
  return campaigns;
});

const hasNoCampaigns = computed(() => !whatsappCampaigns.value?.length);

const openDialog = () => {
  showWhatsAppCampaignDialog.value = !showWhatsAppCampaignDialog.value;
};

const closeDialog = () => {
  showWhatsAppCampaignDialog.value = false;
};

const handleDelete = campaign => {
  selectedCampaign.value = campaign;
  confirmDeleteCampaignDialogRef.value.dialogRef.open();
};
</script>

<template>
  <CampaignLayout
    :header-title="t('CAMPAIGN.WHATSAPP.HEADER_TITLE')"
    :button-label="t('CAMPAIGN.WHATSAPP.NEW_CAMPAIGN')"
    @click="openDialog"
  >
    <template #action>
      <WhatsAppCampaignDialog
        v-if="showWhatsAppCampaignDialog"
        @close="closeDialog"
      />
    </template>

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
