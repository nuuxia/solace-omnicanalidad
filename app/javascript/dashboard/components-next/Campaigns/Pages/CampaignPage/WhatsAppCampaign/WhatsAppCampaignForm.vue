<script setup>
import { reactive, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
// Emisiones: "submit" al crear la campaña, "cancel" al cancelar
const emit = defineEmits(['submit', 'cancel']);
const { t } = useI18n();
// Mapeos del store
const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
};
// Estado inicial
const initialState = {
  title: '',
  inboxId: null,
  selectedWhatsAppTemplate: null,
  selectedAudience: [],
  scheduledAt: null,
  phoneNumber: '', // Sólo para “Send WhatsApp Preview”
};
const state = reactive({ ...initialState });
// Validaciones principales (NO incluye scheduledAt, es opcional)
const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  selectedWhatsAppTemplate: { required },
  selectedAudience: { required },
  scheduledAt: { required },
};
// Vuelidate
const v$ = useVuelidate(rules, state);
// Helpers
const store = useStore();
const selectedInbox = computed(() =>
  formState.inboxes.value.find(inbox => inbox.id === state.inboxId)
);
const isCreating = computed(() => formState.uiFlags.value.isCreating);
const isPreviewing = computed(() => formState.uiFlags.value.isPreviewing);
// Fecha mínima para la hora de programar (date-local input)
const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});
// Crear combos
const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];
const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);
const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);
// Extraer templates de la inbox seleccionada
const whatsappTemplateOptions = computed(() => {
  if (selectedInbox.value?.message_templates) {
    return selectedInbox.value.message_templates.map(template => ({
      value: template.id,
      label: template.name,
    }));
  }
  return [];
});
// Mensajes de error en formulario
const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};
const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('selectedWhatsAppTemplate', 'WHATSAPP_TEMPLATE'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
  // scheduledAt => optional
}));
// Disabled logic para el botón “Create Campaign”
const isSubmitDisabled = computed(() => v$.value.$invalid);
// Validación para “phoneNumber” en el preview (inicia con +, sin espacios)
const validatePhone = phone => {
  return /^\+[^\s]+$/.test(phone);
};
// Para “Send template preview”, requerimos: inbox, template, phoneNumber válido
const isPreviewDisabled = computed(() => {
  if (!state.inboxId) return true;
  if (!state.selectedWhatsAppTemplate) return true;
  if (!validatePhone(state.phoneNumber)) return true;
  return false;
});
// Al resetear, devolvemos a initialState
const resetState = () => {
  Object.assign(state, initialState);
};
const handleCancel = () => emit('cancel');
// Conventir la fecha a UTC
const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;
// Construir payload para crear la campaña
const prepareCampaignDetails = () => ({
  campaigns_whatsapp: {
    title: state.title,
    inbox_id: state.inboxId,
    template: selectedInbox.value?.message_templates.find(
      template => template.id === state.selectedWhatsAppTemplate
    ),
    audience: state.selectedAudience.map(id => ({
      id: Number(id),
      type: 'Label',
    })),
    scheduled_at: formatToUTCString(state.scheduledAt),
  },
});
// Al hacer submit, validamos y emitimos “submit”
const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return; // no pasamos la validación
  const payload = prepareCampaignDetails();
  // eslint-disable-next-line no-console
  console.log('Payload enviado:', prepareCampaignDetails());
  emit('submit', payload);
  resetState();
  handleCancel();
};
// Preview
const phoneError = ref('');
const selectedTemplate = computed(() =>
  selectedInbox.value?.message_templates.find(
    template => template.id === state.selectedWhatsAppTemplate
  )
);
const handleSendPreview = async () => {
  if (!validatePhone(state.phoneNumber)) {
    phoneError.value = t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR');
    return;
  }
  phoneError.value = '';
  // Construir los datos necesarios para la previsualización
  const previewData = {
    inbox_id: state.inboxId,
    template: selectedTemplate.value,
    phone_number: state.phoneNumber,
  };
  try {
    // Despachar la acción 'preview' en el store
    await store.dispatch('campaignsWhatsApp/preview', previewData);
    // Mostrar mensaje de éxito
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.SUCCESS_MESSAGE')
    );
    state.inboxId = null;
    state.selectedWhatsAppTemplate = null;
    state.phoneNumber = '';
  } catch (error) {
    // Manejar errores y mostrar mensaje de error
    const errorMessage =
      error?.message ||
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};
</script>

<template>
  <div class="overflow-y-auto max-h-[80vh] p-4">
    <!-- Form principal: crear campaña -->
    <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
      <!-- Title -->
      <Input
        v-model="state.title"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
        :message="formErrors.title"
        :message-type="formErrors.title ? 'error' : 'info'"
      />
      <!-- Inbox -->
      <div class="flex flex-col gap-1">
        <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
        </label>
        <ComboBox
          id="inbox"
          v-model="state.inboxId"
          :options="inboxOptions"
          :has-error="!!formErrors.inbox"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
          :message="formErrors.inbox"
        />
      </div>
      <!-- WhatsApp Template -->
      <div class="flex flex-col gap-1">
        <label
          for="wa-template"
          class="mb-0.5 text-sm font-medium text-n-slate-12"
        >
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.LABEL') }}
        </label>
        <ComboBox
          id="wa-template"
          v-model="state.selectedWhatsAppTemplate"
          :options="whatsappTemplateOptions"
          :has-error="!!formErrors.template"
          :placeholder="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.PLACEHOLDER')
          "
          :message="formErrors.template"
          :disabled="!state.inboxId"
        />
      </div>
      <!-- Audience multi-select -->
      <div class="flex flex-col gap-1">
        <label
          for="audience"
          class="mb-0.5 text-sm font-medium text-n-slate-12"
        >
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
        </label>
        <TagMultiSelectComboBox
          v-model="state.selectedAudience"
          :options="audienceList"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL')"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
          :has-error="!!formErrors.audience"
          :message="formErrors.audience"
        />
      </div>
      <!-- Scheduled time (OPCIONAL) -->
      <Input
        v-model="state.scheduledAt"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
        type="datetime-local"
        :min="currentDateTime"
        :placeholder="
          t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')
        "
      />
      <!-- Botones: Cancel / Create -->
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          variant="faded"
          color="slate"
          type="button"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
          class="w-full bg-n-alpha-2 n-blue-text hover:bg-n-alpha-3"
          @click="handleCancel"
        />
        <Button
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
          class="w-full"
          type="submit"
          :is-loading="isCreating"
          :disabled="isCreating || isSubmitDisabled"
        />
      </div>
      <!-- Separador fino -->
      <hr class="my-2 border-n-slate-6" />
      <!-- Sección: Send WhatsApp Preview -->
      <div class="flex flex-col gap-2">
        <h3 class="text-base font-medium text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.TITLE') }}
        </h3>
        <Input
          v-model="state.phoneNumber"
          :label="
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PHONE_LABEL')
          "
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
        <!-- Mensaje de error del store -->
        <div
          v-if="formState.uiFlags.value.previewError"
          class="text-red-500 text-xs whitespace-pre-line break-words mt-1"
          v-html="formState.uiFlags.value.previewError"
        />
        <!-- Botón “Send template preview” -->
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
    </form>
  </div>
</template>
