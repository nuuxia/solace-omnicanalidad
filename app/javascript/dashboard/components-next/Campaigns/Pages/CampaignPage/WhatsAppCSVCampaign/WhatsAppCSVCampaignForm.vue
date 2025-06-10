<script setup>
import { reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsappCSVPreviewSection from './WhatsappCSVPreviewSection.vue';

const emit = defineEmits(['submit', 'cancel']);
const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
};

const initialState = {
  title: '',
  inboxId: null,
  selectedWhatsAppTemplate: null,
  selectedAudience: [],
  scheduledAt: null,
  phoneNumber: '',
};

const state = reactive({ ...initialState });

const dynamicFields = reactive({
  headerMediaFile: null,
  displayFileName: '',
});

const bodyVariables = reactive([]);
const buttonVariables = reactive([]);

// VALIDATIONS
const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  selectedWhatsAppTemplate: { required },
  selectedAudience: { required },
  scheduledAt: { required },
};
const v$ = useVuelidate(rules, state);

const areBodyVariablesFilled = computed(() =>
  bodyVariables.every(v => {
    if (v.sourceType === 'text') {
      return v.value.trim() !== '';
    }
    return true;
  })
);

// Para validar placeholders de BUTTONS
const areButtonVariablesFilled = computed(() =>
  buttonVariables.every(btn => {
    if (btn.dynamic) {
      return btn.value.trim() !== '';
    }
    return true;
  })
);

// Para verificar si el template exige un archivo en el header
const needsHeaderFile = computed(() => showMediaHeaderSection.value);

const selectedInbox = computed(() =>
  formState.inboxes.value.find(inbox => inbox.id === state.inboxId)
);
const isCreating = computed(() => formState.uiFlags.value.isCreating);
const isPreviewing = computed(() => formState.uiFlags.value.isPreviewing);

// Fecha mínima (datetime-local)
const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({ value: item[valueKey], label: item[labelKey] })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);
const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

function hasNamedPlaceholders(template) {
  if (!template || !template.components) return false;
  return template.components.some(component => {
    if (!component.text) return false;

    const matches = component.text.match(/\{\{(.*?)\}\}/g);
    if (!matches) return false;

    return matches.some(ph => {
      const inside = ph.replace(/\{\{|}}/g, '').trim();
      return !/^\d+$/.test(inside);
    });
  });
}

const whatsappTemplateOptions = computed(() => {
  if (!selectedInbox.value?.message_templates) {
    return [];
  }
  return selectedInbox.value.message_templates

    .filter(template => !hasNamedPlaceholders(template))
    .map(template => ({
      value: template.id,
      label: template.name,
    }));
});

// Template seleccionado completo
const selectedTemplate = computed(() => {
  if (!state.selectedWhatsAppTemplate) return null;
  return selectedInbox.value?.message_templates?.find(
    t => t.id === state.selectedWhatsAppTemplate
  );
});

// Detectar HEADER (IMAGE, VIDEO, DOCUMENT)
const selectedTemplateHeader = computed(() => {
  return selectedTemplate.value?.components?.find(c => c.type === 'HEADER');
});
const showMediaHeaderSection = computed(() => {
  if (!selectedTemplateHeader.value) return false;
  const format = selectedTemplateHeader.value.format;
  return ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(format);
});

// --- NUEVO: Options para el ComboBox de Body Variables
const bodySourceTypeOptions = computed(() => [
  {
    value: 'text',
    label: t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.FREE_TEXT'),
  },
  {
    value: 'contact_name',
    label: t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.CONTACT_NAME'),
  },
]);

// FORM ERRORS
function getErrorMessage(field, errorKey) {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
}
const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('selectedWhatsAppTemplate', 'WHATSAPP_TEMPLATE'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const isSubmitDisabled = computed(() => {
  return (
    v$.value.$invalid ||
    !areBodyVariablesFilled.value ||
    !areButtonVariablesFilled.value ||
    (needsHeaderFile.value && !dynamicFields.headerMediaFile)
  );
});

function resetState() {
  Object.assign(state, initialState);
  dynamicFields.headerMediaFile = null;
  dynamicFields.displayFileName = '';
  bodyVariables.splice(0, bodyVariables.length);
  buttonVariables.splice(0, buttonVariables.length);
}
function handleCancel() {
  emit('cancel');
}

function formatToUTCString(localDateTime) {
  return localDateTime ? new Date(localDateTime).toISOString() : null;
}

watch(
  () => state.selectedWhatsAppTemplate,
  () => {
    dynamicFields.headerMediaFile = null;
    dynamicFields.displayFileName = '';
    parseTemplateVariables();
  }
);

function parseTemplateVariables() {
  bodyVariables.splice(0, bodyVariables.length);
  buttonVariables.splice(0, buttonVariables.length);

  if (!selectedTemplate.value) return;

  const bodyComp = selectedTemplate.value.components.find(
    c => c.type === 'BODY'
  );
  if (bodyComp?.text) {
    const matches = bodyComp.text.match(/{{(.*?)}}/g);
    if (matches) {
      matches.forEach(() => {
        bodyVariables.push({
          sourceType: 'text',
          value: '',
        });
      });
    }
  }

  const buttonsComp = selectedTemplate.value.components.find(
    c => c.type === 'BUTTONS'
  );
  if (buttonsComp?.buttons?.length) {
    buttonsComp.buttons.forEach(btn => {
      if (btn.type === 'COPY_CODE') {
        buttonVariables.push({
          type: 'COPY_CODE',
          dynamic: true,
          value: '',
        });
      } else if (btn.type === 'URL') {
        if (btn.url && /{{(.*?)}}/.test(btn.url)) {
          buttonVariables.push({
            type: 'URL',
            dynamic: true,
            value: '',
          });
        }
      } else if (btn.type === 'PHONE_NUMBER') {
        if (btn.phone_number && /{{(.*?)}}/.test(btn.phone_number)) {
          buttonVariables.push({
            type: 'PHONE_NUMBER',
            dynamic: true,
            value: '',
          });
        }
      }
    });
  }
}
function getAcceptForHeader(format) {
  switch (format) {
    case 'IMAGE':
      return 'image/jpeg,image/png';
    case 'VIDEO':
      return 'video/mp4';
    case 'DOCUMENT':
      return 'application/pdf';
    default:
      return '*/*';
  }
}
function handleFileChange(event) {
  const file = event.target.files[0];
  if (!file) {
    dynamicFields.headerMediaFile = null;
    dynamicFields.displayFileName = '';
    return;
  }
  dynamicFields.headerMediaFile = file;
  const maxLength = 20;
  dynamicFields.displayFileName =
    file.name.length > maxLength
      ? file.name.slice(0, maxLength) + '...'
      : file.name;
}

// Submit
async function handleSubmit() {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

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

  if (needsHeaderFile.value && !dynamicFields.headerMediaFile) {
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.ERROR_FILE_REQUIRED')
    );
    return;
  }

  const template = selectedTemplate.value
    ? JSON.parse(JSON.stringify(selectedTemplate.value))
    : null;

  const formData = new FormData();
  formData.append('title', state.title || '');
  formData.append('inbox_id', state.inboxId || '');
  if (template) {
    formData.append('template', JSON.stringify(template));
  }

  state.selectedAudience.forEach((id, idx) => {
    formData.append(`audience[${idx}][id]`, id);
    formData.append(`audience[${idx}][type]`, 'Label');
  });

  const sched = formatToUTCString(state.scheduledAt);
  if (sched) {
    formData.append('scheduled_at', sched);
  }

  // Variables y archivo (mismo estilo que en preview)
  formData.append('body_variables', JSON.stringify(bodyVariables));
  formData.append('button_variables', JSON.stringify(buttonVariables));
  if (dynamicFields.headerMediaFile) {
    formData.append('headerMediaFile', dynamicFields.headerMediaFile);
  }
  try {
    emit('submit', formData);
    resetState();
    handleCancel();
  } catch (err) {
    useAlert('Error al crear la campaña. Revisa la consola.');
  }
}

function handlePreviewSuccess() {}
</script>

<template>
  <div class="overflow-y-auto max-h-[80vh] p-4">
    <!-- Form principal -->
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
          :disabled="false"
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

      <!-- Select Media (HEADER) -->
      <div
        v-if="selectedTemplateHeader && showMediaHeaderSection"
        class="flex flex-col gap-1"
      >
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.HEADER_SECTION') }}
        </h4>
        <div
          class="flex flex-col gap-3 p-3 rounded-md border border-solid border-n-slate-7"
        >
          <label class="text-sm font-medium mb-1">
            <span v-if="selectedTemplateHeader.format === 'IMAGE'">
              {{
                t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_IMAGE')
              }}
            </span>
            <span v-else-if="selectedTemplateHeader.format === 'VIDEO'">
              {{
                t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_VIDEO')
              }}
            </span>
            <span v-else-if="selectedTemplateHeader.format === 'DOCUMENT'">
              {{
                t(
                  'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_DOCUMENT'
                )
              }}
            </span>
          </label>
          <div class="file-input-wrapper">
            <input
              class="native-file-input"
              type="file"
              :accept="getAcceptForHeader(selectedTemplateHeader.format)"
              @change="handleFileChange"
            />
          </div>
          <p v-if="dynamicFields.displayFileName" class="text-xs mt-1">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.FILE')
            }}{{ dynamicFields.displayFileName }}
          </p>
        </div>
      </div>

      <!-- Body Variables -->
      <div v-if="bodyVariables.length" class="flex flex-col gap-1">
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.HEADER_SECTION') }}
        </h4>
        <div
          class="flex flex-col gap-3 p-3 rounded-md border border-solid border-n-slate-7"
        >
          <div
            v-for="(v, idx) in bodyVariables"
            :key="idx"
            class="flex flex-col gap-3"
          >
            <label class="text-sm font-medium">
              {{
                t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.VARIABLE_TITLE')
              }}
              #{{ idx + 1 }}
            </label>
            <ComboBox
              v-model="v.sourceType"
              :options="bodySourceTypeOptions"
              :has-error="false"
              :placeholder="
                t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.FREE_TEXT')
              "
              message=""
              :disabled="false"
            />
            <input
              v-if="v.sourceType === 'text'"
              v-model="v.value"
              class="border p-1 rounded text-sm"
              :placeholder="
                t(
                  'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.VARIABLE_PLACE_HOLDER'
                )
              "
            />
          </div>
        </div>
      </div>

      <!-- Buttons (Variables de botones) -->
      <div v-if="buttonVariables.length" class="flex flex-col gap-1">
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{
            t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BUTTONS.HEADER_SECTION')
          }}
        </h4>
        <div
          class="flex flex-col gap-3 p-3 rounded-md border border-solid border-n-slate-7"
        >
          <div
            v-for="(btn, idx) in buttonVariables"
            :key="idx"
            class="flex flex-col gap-1"
          >
            <label class="text-sm font-medium">
              {{
                t(
                  'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BUTTONS.VARIABLE_TITLE'
                )
              }}
              #{{ idx + 1 }} ({{ btn.type }})
            </label>
            <input
              v-if="btn.dynamic"
              v-model="btn.value"
              class="border p-1 rounded text-sm"
              :placeholder="
                t(
                  'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BUTTONS.VARIABLE_PLACE_HOLDER'
                )
              "
            />
          </div>
        </div>
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
          class="w-full bg-n-alpha-2 n-solid -text hover:bg-n-alpha-3"
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
    </form>

    <hr class="my-2 border-n-slate-6" />

    <!-- Sección de preview -->
    <WhatsappCSVPreviewSection
      v-model:phone-number="state.phoneNumber"
      :inbox-id="state.inboxId"
      :selected-whats-app-template="state.selectedWhatsAppTemplate"
      :selected-inbox="selectedInbox"
      :header-media-file="dynamicFields.headerMediaFile"
      :body-variables="bodyVariables"
      :button-variables="buttonVariables"
      :is-previewing="isPreviewing"
      :preview-error="formState.uiFlags.value.previewError"
      @preview-success="handlePreviewSuccess"
    />
  </div>
</template>

<style scoped>
.file-input-wrapper {
  width: 110px;
  overflow: hidden;
  position: relative;
}
.native-file-input::-webkit-file-upload-text {
  visibility: hidden;
  margin: 0;
}
.native-file-input {
  cursor: pointer;
  white-space: nowrap;
  overflow: hidden;
}
</style>
