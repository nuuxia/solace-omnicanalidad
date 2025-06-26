<!-- WhatsAppCSVCampaignStatsDialog.vue -->
<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStore }  from 'vuex';
import { useI18n }   from 'vue-i18n';

import Dialog      from 'dashboard/components-next/dialog/Dialog.vue';
import ProgressBar from 'dashboard/components-next/progress/ProgressBar.vue';
import Button      from 'dashboard/components-next/button/Button.vue';

const props = defineProps({ campaign: { type: Object, required: true } });
const emit  = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);

/* ─── números ─── */
const sent    = computed(() => +props.campaign.messages_sent   || 0);
const total   = computed(() => +props.campaign.messages_total  || 0);
const failed  = computed(() => +props.campaign.messages_failed || 0);
const pending = computed(() => Math.max(total.value - sent.value - failed.value, 0));
const donePct = computed(() =>
  total.value ? Math.round(((sent.value + failed.value) / total.value) * 100) : 0
);

/* ─── links ─── */
const csvStatusURL = props.campaign.csv_sent_url;   // el “estado” que pediste

onMounted(() => dialogRef.value?.open());

const retryFailed = async () => {
  if (!failed.value) return;
  await store.dispatch('campaignsCSVWhatsApp/retryFailed', props.campaign.id);
  emit('close');
};
</script>

<template>
  <Dialog ref="dialogRef"
          :title="t('CAMPAIGN.CSV.WHATSAPP.STATS.TITLE')"
          @close="emit('close')">

    <!-- contenido -->
    <div class="space-y-6 pt-1">

      <!-- barra + % -->
      <div class="flex items-center gap-2">
        <ProgressBar :value="donePct" color="bg-green-500" class="flex-1" />
        <span class="text-sm font-medium text-slate-700 min-w-[40px] text-right">
          {{ donePct }}%
        </span>
      </div>

      <!-- métricas -->
      <div class="grid grid-cols-3 text-center">
        <div>
          <p class="text-xs text-slate-500">{{ t('CAMPAIGN.CSV.WHATSAPP.STATS.SENT') }}</p>
          <p class="font-semibold text-slate-800">{{ sent }}</p>
        </div>
        <div>
          <p class="text-xs text-slate-500">{{ t('CAMPAIGN.CSV.WHATSAPP.STATS.PENDING') }}</p>
          <p class="font-semibold text-slate-800">{{ pending }}</p>
        </div>
        <div>
          <p class="text-xs text-slate-500">{{ t('CAMPAIGN.CSV.WHATSAPP.STATS.FAILED') }}</p>
          <p class="font-semibold text-slate-800">{{ failed }}</p>
        </div>
      </div>

      <!-- estado -->
      <div class="flex justify-center gap-2 text-sm">
        <span class="text-slate-500">{{ t('CAMPAIGN.CSV.WHATSAPP.STATS.STATUS') }}:</span>
        <span class="font-medium"
              :class="pending ? 'text-orange-600' : 'text-green-600'">
          {{ pending ? t('CAMPAIGN.CSV.WHATSAPP.CARD.STATUS.ENABLED')
                     : t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED') }}
        </span>
      </div>
    </div>

    <!-- footer -->
    <template #footer>
      <div class="flex flex-col sm:flex-row sm:items-center sm:gap-2 w-full">

        <!-- descargar CSV del estado -->
        <Button v-if="csvStatusURL"
                as="a"
                :href="csvStatusURL"
                download
                variant="faded"
                size="sm"
                icon="i-lucide-download">
          {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.DOWNLOAD_STATUS') }}
        </Button>

        <!-- re-intentar -->
        <Button v-if="failed"
                color="teal"
                variant="solid"
                size="sm"
                icon="i-lucide-repeat"
                class="sm:ml-auto"
                @click="retryFailed">
          {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.RETRY_BUTTON') }}
        </Button>

        <!-- cerrar -->
        <Button variant="faded"
                size="sm"
                color="slate"
                class="sm:ml-auto"
                @click="emit('close')">
          {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.CANCEL_BUTTON_TEXT') }}
        </Button>
      </div>
    </template>
  </Dialog>
</template>
