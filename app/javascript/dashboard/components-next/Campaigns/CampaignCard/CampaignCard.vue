<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getInboxIconByType } from 'dashboard/helper/inbox';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import LiveChatCampaignDetails from './LiveChatCampaignDetails.vue';
import SMSCampaignDetails from './SMSCampaignDetails.vue';
import WhatsAppCampaignDetails from './WhatsAppCampaignDetails.vue';

const props = defineProps({
  title: {
    type: String,
    default: '',
  },
  message: {
    type: String,
    default: '',
  },
  template: {
    type: [Object, String, null],
    default: null,
  },
  isLiveChatType: {
    type: Boolean,
    default: false,
  },
  isEnabled: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String,
    default: '',
  },
  sender: {
    type: Object,
    default: null,
  },
  inbox: {
    type: Object,
    default: null,
  },
  scheduledAt: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['edit', 'delete']);
const { t } = useI18n();
const STATUS_COMPLETED = 'completed';
const { formatMessage } = useMessageFormatter();

const isWhatsAppInbox = computed(
  () => props.inbox?.channel_type === 'Channel::Whatsapp'
);

const isActive = computed(() =>
  props.isLiveChatType ? props.isEnabled : props.status !== STATUS_COMPLETED
);

const statusTextColor = computed(() => ({
  'text-n-teal-11': isActive.value,
  'text-n-slate-12': !isActive.value,
}));

const campaignStatus = computed(() => {
  if (props.isLiveChatType) {
    return props.isEnabled
      ? t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.ENABLED')
      : t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.DISABLED');
  }
  if (isWhatsAppInbox.value) {
    return props.status === STATUS_COMPLETED
      ? t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
      : t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED');
  }
  return props.status === STATUS_COMPLETED
    ? t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
    : t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED');
});

const inboxName = computed(() => props.inbox?.name || '');

const inboxIcon = computed(() => {
  const { phone_number: phoneNumber, channel_type: type } = props.inbox || {};
  return getInboxIconByType(type, phoneNumber);
});

const parsedTemplate = computed(() => {
  if (!props.template) return null;

  try {
    // Si ya es un objeto y tiene la estructura esperada, retornarlo tal cual
    if (typeof props.template === 'object' && !Array.isArray(props.template)) {
      return props.template;
    }

    // Si es string, intentar parsearlo como JSON
    if (typeof props.template === 'string') {
      const parsed = JSON.parse(props.template);
      if (typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed;
      }
    }

    return null;
  } catch (error) {
    return null;
  }
});

const getTemplateContent = computed(() => {
  const template = parsedTemplate.value;
  if (!template) return '';

  // Si hay componentes, buscar el BODY
  if (template.components && Array.isArray(template.components)) {
    const bodyComponent = template.components.find(c => c.type === 'BODY');
    if (bodyComponent?.text) {
      return bodyComponent.text;
    }
  }

  // Si no hay BODY pero hay nombre del template
  if (template.name) {
    return `Template: ${template.name}`;
  }

  return '';
});

const displayContent = computed(() => {
  if (isWhatsAppInbox.value) {
    const content = getTemplateContent.value;
    return content || props.message || props.title;
  }
  return props.message;
});
</script>

<template>
  <CardLayout class="flex flex-row justify-between flex-1 gap-8" layout="row">
    <template #header>
      <div class="flex flex-col items-start gap-2">
        <div class="flex justify-between gap-3 w-fit">
          <span
            class="text-base font-medium capitalize text-n-slate-12 line-clamp-1"
          >
            {{ title }}
          </span>
          <span
            class="text-xs font-medium inline-flex items-center h-6 px-2 py-0.5 rounded-md bg-n-alpha-2"
            :class="statusTextColor"
          >
            {{ campaignStatus }}
          </span>
        </div>
        <div
          v-if="displayContent"
          v-dompurify-html="formatMessage(displayContent)"
          class="text-sm text-n-slate-11 line-clamp-1 [&>p]:mb-0 h-6"
        />
        <div class="flex items-center w-full h-6 gap-2 overflow-hidden">
          <LiveChatCampaignDetails
            v-if="isLiveChatType"
            :sender="sender"
            :inbox-name="inboxName"
            :inbox-icon="inboxIcon"
          />
          <WhatsAppCampaignDetails
            v-else-if="isWhatsAppInbox"
            :inbox-name="inboxName"
            :inbox-icon="inboxIcon"
            :scheduled-at="scheduledAt"
          />
          <SMSCampaignDetails
            v-else
            :inbox-name="inboxName"
            :inbox-icon="inboxIcon"
            :scheduled-at="scheduledAt"
          />
        </div>
      </div>
    </template>

    <div class="flex items-center justify-end w-20 gap-2">
      <Button
        v-if="isLiveChatType"
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-sliders-vertical"
        @click="emit('edit')"
      />
      <Button
        variant="faded"
        color="ruby"
        size="sm"
        icon="i-lucide-trash"
        @click="emit('delete')"
      />
    </div>
  </CardLayout>
</template>
