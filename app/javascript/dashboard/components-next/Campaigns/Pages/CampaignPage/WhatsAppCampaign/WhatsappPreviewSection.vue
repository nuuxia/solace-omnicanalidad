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
  headerMediaFile: {
    type: [File, null],
    default: null,
  },
  bodyVariables: {
    type: Array,
    default: () => [],
  },
  buttonVariables: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:phoneNumber', 'preview-success']);

const { t } = useI18n();
const store = useStore();

const phoneError = ref('');

// Validamos un teléfono en formato +... (simple)
const validatePhone = phone => /^\+[^\s]+$/.test(phone);

// Para el input del teléfono
const localPhone = computed({
  get() {
    return props.phoneNumber;
  },
  set(value) {
    emit('update:phoneNumber', value);
  },
});

// Computar la plantilla seleccionada
const selectedTemplate = computed(() => {
  return props.selectedInbox?.message_templates?.find(
    template => template.id === props.selectedWhatsAppTemplate
  );
});

// Deshabilitar el botón de preview
const isPreviewDisabled = computed(() => {
  if (!props.inboxId) return true;
  if (!props.selectedWhatsAppTemplate) return true;
  if (!validatePhone(props.phoneNumber)) return true;
  return false;
});

// Enviar preview
const handleSendPreview = async () => {
  if (!validatePhone(props.phoneNumber)) {
    phoneError.value = t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR');
    return;
  }
  phoneError.value = '';

  // Armamos el objeto con todo lo necesario
  const previewData = {
    inboxId: props.inboxId,
    phoneNumber: props.phoneNumber,
    template: selectedTemplate.value,
    headerMediaFile: props.headerMediaFile,
    bodyVariables: props.bodyVariables, // <-- Agregar bodyVariables
    buttonVariables: props.buttonVariables, // <-- Agregar buttonVariable
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

    <!-- Error de teléfono -->
    <div
      v-if="phoneError"
      class="text-red-500 text-xs whitespace-pre-line break-words mt-1"
      v-html="phoneError"
    />

    <!-- Error de preview -->
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
