<script setup>
/* ────────────────── imports ────────────────── */
import { ref, onMounted, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { messageStamp } from 'shared/helpers/timeHelper';
import { useAlert } from 'dashboard/composables'; // Import useAlert

import Dialog      from 'dashboard/components-next/dialog/Dialog.vue';
import ProgressBar from 'dashboard/components-next/progress/ProgressBar.vue';
import Button      from 'dashboard/components-next/button/Button.vue';

/* ────────────────── props / emits ────────────────── */
const props = defineProps({ campaign: { type: Object, required: true } });
const emit  = defineEmits(['close']);

/* ────────────────── store & i18n ────────────────── */
const store     = useStore();
const { t }     = useI18n();
const dialogRef = ref(null);

/* ─────────── métricas de envío ─────────── */
const sent    = computed(() => +props.campaign.messages_sent   || 0);
const total   = computed(() => +props.campaign.messages_total  || 0);
const failed  = computed(() => +props.campaign.messages_failed || 0);
const pending = computed(() =>
  Math.max(total.value - sent.value - failed.value, 0)
);
/* % SOLO de enviados correctos */
const donePct = computed(() =>
  total.value ? Math.round((sent.value / total.value) * 100) : 0
);

/* ─────────── CSV links ─────────── */
const csvOriginalURL = props.campaign.csv_original_url;
const csvSentURL     = props.campaign.csv_sent_url;
const csvErrorsURL   = props.campaign.csv_errors_url;

/* descarga programática para evitar bloqueos de navegación SPA */
function downloadCSV(url) {
  if (!url) return;
  const a = document.createElement('a');
  a.href = url;
  a.setAttribute('download', '');
  a.setAttribute('target', '_blank');
  document.body.appendChild(a);
  a.click();
  a.remove();
}

/* ─────────── template (HEADER + BODY + FOOTER) ─────────── */
const parsedTemplate = computed(() => {
  const tpl = props.campaign.template;
  if (!tpl) return null;
  try { return typeof tpl === 'string' ? JSON.parse(tpl) : tpl; }
  catch { return null; }
});

const templatePreview = computed(() =>
  parsedTemplate.value?.components
    ?.filter(c => ['HEADER', 'BODY'].includes(c.type) && c.text)
    ?.map(c => c.text)
    ?.join('\n') || ''
);

const footerText = computed(
  () => parsedTemplate.value?.components?.find(c => c.type === 'FOOTER')?.text || ''
);

/* ─────────── datos extra solicitados ─────────── */
const campaignTitle = computed(() => props.campaign.title || '');
const templateName  = computed(() => parsedTemplate.value?.name || '');
const inboxName     = computed(() => props.campaign.inbox?.name || '');
const scheduledAt   = computed(() =>
  props.campaign.scheduled_at
    ? messageStamp(props.campaign.scheduled_at, 'MMM d, h:mm a')
    : ''
);

/* ─────────── clases para pill de estado ─────────── */
const statusClasses = computed(() =>
  pending.value ? 'text-orange-700 bg-orange-50' : 'text-green-700 bg-green-50'
);

/* ─────────── Debounce logic for retry button ─────────── */
const isRetryButtonDisabled = ref(false);
let retryTimeout = null;

/* ─────────── lifecycle ─────────── */
onMounted(() => dialogRef.value?.open());

/* ─────────── acciones ─────────── */
const retryFailed = async () => {
  if (!failed.value || isRetryButtonDisabled.value) {
    return;
  }

  isRetryButtonDisabled.value = true; // Disable the button immediately

  try {
    await store.dispatch('campaignsCSVWhatsApp/retry', props.campaign.id);
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.STATS.RETRY_SUCCESS')); // Success alert
    emit('close'); // Close the dialog on success
  } catch (error) {
    console.error('Failed to retry campaign:', error);
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.STATS.RETRY_ERROR'), 'error'); // Error alert
  } finally {
    // Re-enable the button after 3 seconds
    retryTimeout = setTimeout(() => {
      isRetryButtonDisabled.value = false;
    }, 3000);
  }
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CAMPAIGN.CSV.WHATSAPP.STATS.TITLE')"
    @close="emit('close')"
  >
    <div class="space-y-6 pt-1">
      <div class="grid gap-1 text-sm text-slate-700">
        <div>
          <span class="font-semibold text-slate-900">
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.TITLE_CAMPAIGN') }}:
          </span>
          {{ campaignTitle }}
        </div>
        <div v-if="templateName">
          <span class="font-semibold text-slate-900">
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.TEMPLATE_NAME') }}:
          </span>
          {{ templateName }}
        </div>
        <div v-if="inboxName">
          <span class="font-semibold text-slate-900">
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.INBOX') }}:
          </span>
          {{ inboxName }}
        </div>
        <div v-if="scheduledAt">
          <span class="font-semibold text-slate-900">
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.SCHEDULED_AT') }}:
          </span>
          {{ scheduledAt }}
        </div>
      </div>

      <div v-if="templatePreview" class="space-y-2">
        <p class="text-xs font-semibold text-slate-900">
          {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.PREVIEW') }}
        </p>
        <pre
          class="whitespace-pre-line rounded border border-slate-200 bg-slate-50 p-3 text-sm text-slate-800 overflow-x-auto"
        >{{ templatePreview }}</pre>
      </div>

      <div v-if="footerText" class="space-y-1">
        <p class="text-xs font-semibold text-slate-900">
          {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.FOOTER') }}
        </p>
        <p class="whitespace-pre-line text-sm text-slate-700">{{ footerText }}</p>
      </div>

      <div class="space-y-1">
        <p class="text-xs font-semibold text-slate-900">
          {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.SUCCESS_RATE') }}
        </p>
        <div class="flex items-center gap-2">
          <ProgressBar :value="donePct" color="bg-violet-600" class="flex-1" />
          <span class="text-sm font-medium text-slate-700 min-w-[40px] text-right">
            {{ donePct }}%
          </span>
        </div>
      </div>

      <div class="flex justify-center gap-4">
        <div class="text-center">
          <p class="text-xs text-slate-500">
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.SENT') }}
          </p>
          <p class="font-semibold text-slate-800">{{ sent }}</p>
        </div>
        <div class="text-center">
          <p class="text-xs text-slate-500">
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.FAILED') }}
          </p>
          <p class="font-semibold text-slate-800">{{ failed }}</p>
        </div>
      </div>

      <div class="flex justify-center gap-2 text-sm">
        <span class="font-semibold text-slate-900">
          {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.STATUS') }}:
        </span>
        <span
          class="px-2 py-0.5 rounded-full text-xs font-semibold"
          :class="statusClasses"
        >
          {{
            pending
              ? t('CAMPAIGN.CSV.WHATSAPP.CARD.STATUS.ENABLED')
              : t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
          }}
        </span>
      </div>
    </div>

    <template #footer>
      <div class="flex w-full flex-col gap-4">
        <div class="flex justify-center gap-2">
          <Button
            v-if="csvOriginalURL"
            variant="faded"
            size="sm"
            icon="i-lucide-download"
            @click="downloadCSV(csvOriginalURL)"
          >
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.DOWNLOAD_ORIGINAL') }}
          </Button>

          <Button
            v-if="csvSentURL"
            variant="faded"
            size="sm"
            icon="i-lucide-download"
            @click="downloadCSV(csvSentURL)"
          >
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.DOWNLOAD_SENT') }}
          </Button>

          <Button
            v-if="csvErrorsURL"
            variant="faded"
            size="sm"
            icon="i-lucide-download"
            @click="downloadCSV(csvErrorsURL)"
          >
            {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.DOWNLOAD_ERRORS') }}
          </Button>
        </div>

        <div class="flex w-full justify-between">
          <div>
            <Button
              v-if="failed"
              color="teal"
              variant="solid"
              size="sm"
              icon="i-lucide-repeat"
              @click="retryFailed"
              :disabled="isRetryButtonDisabled" >
              {{ t('CAMPAIGN.CSV.WHATSAPP.STATS.RETRY_BUTTON') }}
            </Button>
          </div>

          <div>
            <Button
              variant="faded"
              size="sm"
              color="slate"
              @click="emit('close')"
            >
              {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.CANCEL_BUTTON_TEXT') }}
            </Button>
          </div>
        </div>
      </div>
    </template>
  </Dialog>
</template>