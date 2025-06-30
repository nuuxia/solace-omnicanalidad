<!-- WhatsAppCSVCampaignDialog.vue -->
<script setup>
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert, useTrack } from 'dashboard/composables';
import { CAMPAIGN_TYPES } from 'shared/constants/campaign.js';
import { CAMPAIGNS_EVENTS } from 'dashboard/helper/AnalyticsHelper/events.js';

import WhatsAppCSVCampaignForm from './WhatsAppCSVCampaignForm.vue';

const emit  = defineEmits(['close']);
const store = useStore();
const { t } = useI18n();

/* ───────── crear campaña ───────── */
const createCampaign = async fd => {
  try {
    await store.dispatch('campaignsCSVWhatsApp/create', fd);
    useTrack(CAMPAIGNS_EVENTS.CREATE_CAMPAIGN, {
      type: CAMPAIGN_TYPES.ONE_OFF,
    });
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (e) {
    useAlert(
      e?.response?.message ??
        t('CAMPAIGN.WHATSAPP.CREATE.FORM.API.ERROR_MESSAGE')
    );
  }
};

const handlePreview = async previewData => {
  try {
    await store.dispatch('campaignsWhatsApp/preview', previewData);
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.SUCCESS_MESSAGE')
    );
  } catch (e) {
    useAlert(
      e?.message ||
        t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_MESSAGE')
    );
  }
};

</script>

<template>
  <!-- Overlay -->
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    @click.self="emit('close')"
  >
    <!-- Diálogo -->
    <section
      class="relative w-full max-w-[70rem] max-h-[90vh] bg-n-alpha-3 backdrop-blur-[80px] rounded-2xl border border-n-slate-6 dark:border-slate-800 shadow-xl flex flex-col"
    >
      <!-- Header -->
      <header
        class="flex items-center justify-between px-6 py-4 border-b border-n-slate-6 dark:border-slate-800"
      >
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.TITLE') }}
        </h2>
        <!-- (ya no hay botón Sync aquí) -->
      </header>

      <!-- Body -->
      <main class="flex-1 overflow-y-auto">
        <WhatsAppCSVCampaignForm
          @submit="createCampaign"
          @cancel="emit('close')"
          @preview="handlePreview"
        />
      </main>
    </section>
  </div>
</template>
