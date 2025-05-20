<script setup>
import { ref, computed } from 'vue';
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

// Validamos que el teléfono:
// Debe iniciar con '+', luego solo dígitos, sin espacios
const validatePhone = phone => {
  return /^\+\d+$/.test(phone);
};

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

// Reglas para placeholders (similar a lo que hicimos en el form)
const areBodyVariablesFilled = computed(() =>
  props.bodyVariables.every(v => {
    if (v.sourceType === 'text') {
      return v.value.trim() !== '';
    }
    return true;
  })
);

const areButtonVariablesFilled = computed(() =>
  props.buttonVariables.every(btn => {
    if (btn.dynamic) {
      return btn.value.trim() !== '';
    }
    return true;
  })
);

// Para verificar si el template exige un archivo en el header
const hasMediaHeader = computed(() => {
  if (!selectedTemplate.value) return false;
  const header = selectedTemplate.value.components?.find(
    c => c.type === 'HEADER'
  );
  if (!header) return false;
  return ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(header.format);
});

// Deshabilitar el botón de preview
const isPreviewDisabled = computed(() => {
  // 1) Inbox y template son obligatorios
  if (!props.inboxId) return true;
  if (!props.selectedWhatsAppTemplate) return true;

  // 2) Phone debe ser válido
  if (!validatePhone(props.phoneNumber)) return true;

  // 3) Variables deben estar llenas
  if (!areBodyVariablesFilled.value) return true;
  if (!areButtonVariablesFilled.value) return true;

  // 4) Si el template necesita archivo y no se ha cargado
  if (hasMediaHeader.value && !props.headerMediaFile) return true;

  return false;
});

// Enviar preview
const handleSendPreview = async () => {
  /**
   * 1) Guardamos el número *actual* y lo limpiamos inmediatamente.
   *    Así evitamos que se pueda disparar varias veces con la misma info.
   */
  const currentPhone = localPhone.value;
  localPhone.value = ''; // <-- Se limpia "ni bien" se hace clic

  // Valida teléfono con la variable "currentPhone"
  if (!validatePhone(currentPhone)) {
    phoneError.value = t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR');
    return;
  }
  phoneError.value = '';

  // Chequear placeholders
  if (!areBodyVariablesFilled.value) {
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.ERROR_PLACEHOLDERS')
    );
    return;
  }
  if (!areButtonVariablesFilled.value) {
    useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.ERROR_EMPTY_URL'));
    return;
  }

  // 4) Verifica si el template exige archivo y no se ha cargado
  if (hasMediaHeader.value && !props.headerMediaFile) {
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.ERROR_FILE_REQUIRED')
    );
    return;
  }

  // Armamos el objeto con todo lo necesario
  const previewData = {
    inboxId: props.inboxId,
    phoneNumber: currentPhone,
    template: selectedTemplate.value,
    headerMediaFile: props.headerMediaFile,
    bodyVariables: props.bodyVariables,
    buttonVariables: props.buttonVariables,
  };

  try {
    await store.dispatch('campaignsWhatsApp/preview', previewData);
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.SUCCESS_MESSAGE')
    );
    emit('preview-success');
    // NOTA: No reestablecemos phoneNumber aquí,
    //       porque ya lo limpiamos arriba "inmediatamente".
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
      :is-loading="isPreviewing"
      @click="handleSendPreview"
    />
  </div>
</template>
