<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { messageStamp } from 'shared/helpers/timeHelper';
import { useI18n } from 'vue-i18n';
defineProps({
  inboxName: {
    type: String,
    default: '',
  },
  inboxIcon: {
    type: String,
    default: '',
  },
  scheduledAt: {
    type: Number,
    default: 0,
  },
});
const { t } = useI18n();
</script>

<template>
  <div class="flex items-center gap-2">
    <span class="text-sm text-n-slate-11 whitespace-nowrap">
      {{ t('CAMPAIGN.WHATSAPP.CARD.CAMPAIGN_DETAILS.SENT_FROM') }}
    </span>
    <div class="flex items-center gap-1.5">
      <Icon :icon="inboxIcon" class="text-n-slate-12 size-3" />
      <span class="text-sm font-medium text-n-slate-12">
        {{ inboxName }}
      </span>
    </div>
    <span class="text-sm text-n-slate-11 whitespace-nowrap">
      {{ t('CAMPAIGN.WHATSAPP.CARD.CAMPAIGN_DETAILS.ON') }}
    </span>
    <span class="text-sm font-medium text-n-slate-12">
      {{ messageStamp(scheduledAt, 'MMM d, yyyy h:mm a') }}
    </span>
  </div>
</template>
