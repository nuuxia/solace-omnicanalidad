<script setup>
import { ref, computed, defineProps, defineEmits } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  phoneNumber: {
    type: String,
    default: '',
  },
  inboxId: {
    type: [Number, String],
    default: null,
  },
  selectedWhatsAppTemplate: {
    type: [Number, String],
    default: null,
  },
  selectedInbox: {
    type: Object,
    default: null,
  },
  isPreviewing: {
    type: Boolean,
    default: false,
  },
  previewError: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:phoneNumber', 'preview-success']);

const { t } = useI18n();
const store = useStore();

const phoneError = ref('');

const validatePhone = phone => /^\+[^\s]+$/.test(phone);

// Configuración para v-model en el input de teléfono
const localPhone = computed({
  get() {
    return props.phoneNumber;
  },
  set(value) {
    emit('update:phoneNumber', value);
  },
});

// Computar la plantilla seleccionada a partir de la inbox y el template seleccionado
const selectedTemplate = computed(() => {
  return props.selectedInbox?.message_templates?.find(
    template => template.id === props.selectedWhatsAppTemplate
  );
});

// Lógica para deshabilitar el botón de preview
const isPreviewDisabled = computed(() => {
  if (!props.inboxId) return true;
  if (!props.selectedWhatsAppTemplate) return true;
  if (!validatePhone(props.phoneNumber)) return true;
  return false;
});

const handleSendPreview = async () => {
  if (!validatePhone(props.phoneNumber)) {
    phoneError.value = t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR');
    return;
  }
  phoneError.value = '';
  const previewData = {
    inbox_id: props.inboxId,
    template: selectedTemplate.value,
    phone_number: props.phoneNumber,
  };
  try {
    await store.dispatch('campaignsWhatsApp/preview', previewData);
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.SUCCESS_MESSAGE')
    );
    emit('preview-success');
  } catch (error) {
    const errorMessage =
      error?.message ||
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <h3 class="text-base font-medium text-n-slate-12">
      {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.TITLE') }}
    </h3>
    <Input
      v-model="localPhone"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PHONE_LABEL')"
      :placeholder="
        t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PLACEHOLDER')
      "
      message-class="whitespace-pre-line break-words !overflow-visible"
    />
    <div
      v-if="phoneError"
      class="text-red-500 text-xs whitespace-pre-line break-words mt-1"
      v-html="phoneError"
    />
    <div
      v-if="previewError"
      class="text-red-500 text-xs whitespace-pre-line break-words mt-1"
      v-html="previewError"
    />
    <Button
      type="button"
      :label="
        isPreviewing
          ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.LOADING_LABEL')
          : t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.BUTTON_LABEL')
      "
      :disabled="isPreviewDisabled || isPreviewing"
      @click="handleSendPreview"
      :is-loading="isPreviewing"
    />
  </div>
</template>
