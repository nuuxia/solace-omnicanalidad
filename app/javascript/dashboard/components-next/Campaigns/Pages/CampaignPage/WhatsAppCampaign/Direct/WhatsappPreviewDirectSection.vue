<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  phoneNumber: { type: String, default: '' },
  inboxId: { type: [Number, String], default: null },
  selectedWhatsAppTemplate: { type: [Number, String], default: null },
  selectedInbox: { type: Object, default: null },
  isPreviewing: { type: Boolean, default: false },
  previewError: { type: String, default: '' },
  headerMediaFile: { type: [File, null], default: null },
  bodyVariables: { type: Array, default: () => [] },
  buttonVariables: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:phoneNumber', 'preview-success']);

const { t } = useI18n();
const store = useStore();

const phoneError = ref('');

const validatePhone = phone => /^\+\d{6,15}$/.test(phone);

// Phone local
const localPhone = computed({
  get: () => props.phoneNumber,
  set: value => emit('update:phoneNumber', value),
});

// Template seleccionado
const selectedTemplate = computed(() =>
  props.selectedInbox?.message_templates?.find(
    t => t.id === props.selectedWhatsAppTemplate
  )
);

// Validaciones de placeholders
const areBodyVariablesFilled = computed(() =>
  props.bodyVariables.every(v =>
    v.sourceType === 'text' ? v.value.trim() !== '' : true
  )
);

const areButtonVariablesFilled = computed(() =>
  props.buttonVariables.every(b =>
    b.dynamic ? b.value.trim() !== '' : true
  )
);

// Header media
const hasMediaHeader = computed(() => {
  const header = selectedTemplate.value?.components?.find(c => c.type === 'HEADER');
  return header ? ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(header.format) : false;
});

// Deshabilitar botón de preview
const isPreviewDisabled = computed(() =>
  !props.inboxId ||
  !props.selectedWhatsAppTemplate ||
  !validatePhone(props.phoneNumber) ||
  !areBodyVariablesFilled.value ||
  !areButtonVariablesFilled.value ||
  (hasMediaHeader.value && !props.headerMediaFile)
);

// ENVIAR PREVIEW ────────────────
const handleSendPreview = async () => {
  const currentPhone = localPhone.value;
  localPhone.value = '';

  if (!validatePhone(currentPhone)) {
    phoneError.value = t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_PLUS');
    return;
  }
  phoneError.value = '';

  if (!areBodyVariablesFilled.value) {
    return useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.ERROR_PLACEHOLDERS'));
  }
  if (!areButtonVariablesFilled.value) {
    return useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.ERROR_EMPTY_URL'));
  }
  if (hasMediaHeader.value && !props.headerMediaFile) {
    return useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.ERROR_FILE_REQUIRED'));
  }

  // SIEMPRE enviamos FormData (necesario si hay archivo)
  const fd = new FormData();
  fd.append('inbox_id', props.inboxId);
  fd.append('phone_number', currentPhone);
  fd.append('template', JSON.stringify(selectedTemplate.value));
  fd.append('body_variables', JSON.stringify(props.bodyVariables));
  fd.append('button_variables', JSON.stringify(props.buttonVariables));
  if (props.headerMediaFile) fd.append('headerMediaFile', props.headerMediaFile);

  try {
    await store.dispatch('campaignsWhatsApp/previewDirectCampaign', fd);
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.SUCCESS_MESSAGE'));
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

    <!-- Errores -->
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
