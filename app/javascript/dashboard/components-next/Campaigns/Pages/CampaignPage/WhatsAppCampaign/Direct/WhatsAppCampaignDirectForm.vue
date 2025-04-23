<!-- -----------------------------------------------------------------------
  CreateWhatsAppDirectCampaignForm.vue  (v6 – 22‑Abr‑2025)
  · FIX: uiFlags puede llegar como undefined al montar -> defensas
  · FIX: todas las lecturas de uiFlags usan valor por defecto {}
  · Mantiene los arreglos anteriores (HEADER null‑safe, validaciones, etc.)
-------------------------------------------------------------------------- -->

<script setup>
import { reactive, ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, helpers } from '@vuelidate/validators';

import Papa from 'papaparse';
import * as XLSX from 'xlsx';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

/* ───────────────────────── i18n & emits ─────────────────────────────── */
const { t } = useI18n();
const emit  = defineEmits(['submit', 'cancel', 'preview']);

/* ───────────────────────── estado global ─────────────────────────────── */
const formState = {
  uiFlags : useMapGetter('campaignsWhatsapp/getUIFlags'),
  inboxes : useMapGetter('inboxes/getWhatsAppInboxes'),
};

/* uiFlags con valor seguro (evita TypeError al inicio) */
const safeUIFlags = computed(
  () => formState.uiFlags?.value || {
    isCreating  : false,
    isPreviewing: false,
    previewError: null,
  }
);

/* ───────────────────────── estado local ──────────────────────────────── */
const initialState = {
  title: '',
  inboxId: null,
  selectedWhatsAppTemplate: null,
  scheduledAt: null,
  phoneNumber: '',
};
const state = reactive({ ...initialState });

const files = reactive({
  contactsFile: null,
  contactsFileName: '',
  headerMediaFile: null,
  headerMediaName: '',
});

const csvColumns      = ref([]);
const bodyVariables   = reactive([]);
const buttonVariables = reactive([]);

/* flags UI (usan safeUIFlags) */
const isCreating   = computed(() => safeUIFlags.value.isCreating);
const isPreviewing = computed(() => safeUIFlags.value.isPreviewing);

/* ───────────────────────── VALIDACIÓN ────────────────────────────────── */
const startsWithPlus = helpers.withMessage(
  t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_PLUS'),
  v => !v || /^\+\d{6,15}$/.test(v)
);

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  selectedWhatsAppTemplate: { required },
  contactsFile: { required },
  scheduledAt: { required },
  phoneNumber: { startsWithPlus },
};

const v$ = useVuelidate(rules, {
  ...state,
  contactsFile: computed(() => files.contactsFile),
});

/* ───────────────────────── Computeds helpers ─────────────────────────── */
const selectedInbox = computed(() =>
  formState.inboxes.value.find(i => i.id === state.inboxId)
);

const hasNamedPlaceholders = tpl =>
  tpl?.components?.some(c =>
    c.text?.match(/{{(.*?)}}/g)
      ?.some(ph => !/^\d+$/.test(ph.replace(/\{|}/g, '')))
  );

const whatsappTemplateOptions = computed(() =>
  selectedInbox.value?.message_templates
    ?.filter(tpl => !hasNamedPlaceholders(tpl))
    .map(tpl => ({ value: tpl.id, label: tpl.name })) ?? []
);

const selectedTemplate = computed(() =>
  selectedInbox.value?.message_templates?.find(
    t => t.id === state.selectedWhatsAppTemplate
  )
);

const selectedHeader = computed(() =>
  selectedTemplate.value?.components?.find(c => c.type === 'HEADER') ?? null
);

const showMediaHeader = computed(() =>
  ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(selectedHeader.value?.format || '')
);

const headerAcceptMime = fmt => ({
  IMAGE: 'image/jpeg,image/png',
  VIDEO: 'video/mp4',
  DOCUMENT: 'application/pdf',
}[fmt] || '*/*');

const areBodyVarsFilled   = computed(() =>
  bodyVariables.every(v => v.sourceType !== 'text' || v.value.trim())
);
const areButtonVarsFilled = computed(() =>
  buttonVariables.every(b => !b.dynamic || b.value.trim())
);

const isCreateDisabled = computed(
  () =>
    v$.value.$invalid ||
    !areBodyVarsFilled.value ||
    !areButtonVarsFilled.value ||
    !files.contactsFile ||
    (showMediaHeader.value && !files.headerMediaFile)
);

const isPreviewDisabled = computed(
  () =>
    v$.value.phoneNumber.$invalid ||
    !state.phoneNumber ||
    !state.inboxId ||
    !state.selectedWhatsAppTemplate ||
    !areBodyVarsFilled.value ||
    !areButtonVarsFilled.value ||
    (showMediaHeader.value && !files.headerMediaFile)
);

/* ─────────────────────── CSV / XLS helpers ───────────────────────────── */
const validateHeaders = headers => {
  const lower   = headers.map(h => h.trim().toLowerCase());
  const missing = ['phone_number', 'status'].filter(r => !lower.includes(r));
  return { valid: !missing.length, missing };
};
const processHeaders = headers => {
  const { valid, missing } = validateHeaders(headers);
  if (!valid) {
    useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.CONTACTS_FILE.MISSING_COLUMNS', {
        cols: missing.join(', '),
      })
    );
    files.contactsFile = null;
    files.contactsFileName = '';
    csvColumns.value = [];
    return;
  }
  csvColumns.value = headers.filter(Boolean).map(h => h.trim());
};
function handleContactsChange(e) {
  const file = e.target.files[0];
  if (!file) {
    files.contactsFile = null;
    files.contactsFileName = '';
    csvColumns.value = [];
    return;
  }
  const ext = file.name.split('.').pop().toLowerCase();
  files.contactsFile = file;
  files.contactsFileName = file.name;

  const reader = new FileReader();
  reader.onload = evt => {
    if (ext === 'csv') {
      const res = Papa.parse(evt.target.result, { header: true, preview: 1 });
      processHeaders(res.meta.fields || []);
    } else if (['xls', 'xlsx'].includes(ext)) {
      const wb = XLSX.read(evt.target.result, { type: 'array' });
      const ws = wb.Sheets[wb.SheetNames[0]];
      const arr = XLSX.utils.sheet_to_json(ws, { header: 1, range: 0, blankrows: false });
      processHeaders(arr[0] || []);
    } else {
      useAlert(t('CAMPAIGN.WHATSAPP.CREATE.FORM.CONTACTS_FILE.INVALID_FORMAT'));
      files.contactsFile = null;
      files.contactsFileName = '';
      csvColumns.value = [];
    }
  };
  if (ext === 'csv') reader.readAsText(file);
  else reader.readAsArrayBuffer(file);
}

/* HEADER media */
function handleHeaderChange(e) {
  const f = e.target.files[0];
  files.headerMediaFile = f ?? null;
  const maxLen = 30;
  files.headerMediaName = f
    ? f.name.length > maxLen
      ? f.name.slice(0, maxLen) + '…'
      : f.name
    : '';
}

/* Cambios de plantilla → re‑parse placeholders */
watch(() => state.selectedWhatsAppTemplate, parseTemplateVars);
function parseTemplateVars() {
  bodyVariables.splice(0);
  buttonVariables.splice(0);
  if (!selectedTemplate.value) return;

  const body = selectedTemplate.value.components.find(c => c.type === 'BODY');
  body?.text?.match(/{{(.*?)}}/g)?.forEach(() =>
    bodyVariables.push({ sourceType: 'text', value: '' })
  );

  const btnComp = selectedTemplate.value.components.find(
    c => c.type === 'BUTTONS'
  );
  btnComp?.buttons?.forEach(btn => {
    if (btn.type === 'COPY_CODE')
      buttonVariables.push({ type: 'COPY_CODE', dynamic: true, value: '' });
    if (btn.type === 'URL' && /{{(.*?)}}/.test(btn.url))
      buttonVariables.push({ type: 'URL', dynamic: true, value: '' });
    if (btn.type === 'PHONE_NUMBER' && /{{(.*?)}}/.test(btn.phone_number))
      buttonVariables.push({ type: 'PHONE_NUMBER', dynamic: true, value: '' });
  });
}

/* ───────────────────────── Submit / Cancel ───────────────────────────── */
const toUTC = local => (local ? new Date(local).toISOString() : null);

async function handleSubmit() {
  if (!(await v$.value.$validate())) return;
  if (!areBodyVarsFilled.value) {
    return useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.ERROR_PLACEHOLDERS')
    );
  }
  if (!areButtonVarsFilled.value) {
    return useAlert(
      t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.ERROR_EMPTY_URL')
    );
  }

  const fd = new FormData();
  fd.append('title', state.title);
  fd.append('inbox_id', state.inboxId);
  fd.append('template', JSON.stringify(selectedTemplate.value));
  fd.append('scheduled_at', toUTC(state.scheduledAt));
  fd.append('contacts_file', files.contactsFile);
  fd.append('body_variables', JSON.stringify(bodyVariables));
  fd.append('button_variables', JSON.stringify(buttonVariables));
  if (files.headerMediaFile) fd.append('headerMediaFile', files.headerMediaFile);

  emit('submit', fd); // → campaignsWhatsapp/createDirectCampaign
  resetForm();
}

function resetForm() {
  Object.assign(state, initialState);
  Object.keys(files).forEach(k => (files[k] = k.includes('Name') ? '' : null));
  csvColumns.value = [];
  bodyVariables.splice(0);
  buttonVariables.splice(0);
}

const handleCancel = () => emit('cancel');
</script>

<template>
  <div class="overflow-y-auto max-h-[80vh] p-6 space-y-6">
    <!-- Contacts file -->
    <div class="space-y-1">
      <label class="block text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.CONTACTS_FILE.LABEL') }}
      </label>

      <label
        for="contacts-upload"
        class="flex items-center justify-center gap-2 px-4 py-2 bg-n-alpha-3
               border border-dashed border-n-slate-7 rounded-md text-sm cursor-pointer
               hover:bg-n-alpha-4"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none"
             viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M12 12V4m0 0l-4 4m4-4l4 4"/>
        </svg>
        <span>{{ files.contactsFileName || 'Choose File' }}</span>
      </label>
      <input id="contacts-upload" type="file" accept=".csv,.xls,.xlsx"
             class="sr-only" @change="handleContactsChange" />

      <p v-if="v$.contactsFile.$error" class="text-xs text-red-500 mt-1">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.CONTACTS_FILE.ERROR') }}
      </p>
    </div>

    <!-- GRID -->
    <div class="grid gap-6 md:grid-cols-2">
      <!-- Columna A -->
      <div class="space-y-6">
        <!-- Title -->
        <Input v-model="state.title"
               :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
               :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
               :message="v$.title.$error ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.ERROR') : ''"
               :message-type="v$.title.$error ? 'error' : 'info'"/>

        <!-- Template -->
        <div>
          <label class="mb-1 text-sm font-medium text-n-slate-12 block">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.LABEL') }}
          </label>
          <ComboBox
            v-model="state.selectedWhatsAppTemplate"
            :options="whatsappTemplateOptions"
            :placeholder="
              t('CAMPAIGN.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.PLACEHOLDER')
            "
            :has-error="v$.selectedWhatsAppTemplate.$error"
            :message="
              v$.selectedWhatsAppTemplate.$error
                ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.ERROR')
                : ''
            "
            :disabled="!state.inboxId"
          />
        </div>

        <!-- Body variables -->
        <div v-if="bodyVariables.length" class="space-y-3">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.HEADER_SECTION') }}
          </h4>
          <div v-for="(v, idx) in bodyVariables" :key="idx"
               class="flex flex-col md:flex-row md:items-center gap-2 bg-n-alpha-3
                      border border-n-slate-8 rounded-md p-3">
            <ComboBox v-model="v.sourceType" class="md:w-1/3"
                      :options="[{value:'text',label:'Text'},...csvColumns.map(c=>({value:c,label:c}))]" />
            <input v-if="v.sourceType === 'text'" v-model="v.value"
                   class="flex-1 bg-transparent border border-n-slate-7 rounded
                          px-2 py-1 text-sm placeholder-n-slate-11 focus:outline-none"
                   :placeholder="
                     t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.VARIABLE_PLACE_HOLDER')
                   "/>
          </div>
        </div>

        <!-- Teléfono preview -->
        <Input v-model="state.phoneNumber"
               :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PHONE_LABEL')"
               :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PLACEHOLDER')"
               :message="v$.phoneNumber.$error ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_PLUS') : ''"
               :message-type="v$.phoneNumber.$error ? 'error' : 'info'"/>
      </div>

      <!-- Columna B -->
      <div class="space-y-6">
        <!-- Inbox -->
        <div>
          <label class="mb-1 text-sm font-medium text-n-slate-12 block">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
          </label>
          <ComboBox
            v-model="state.inboxId"
            :options="formState.inboxes.value?.map(i=>({value:i.id,label:i.name})) ?? []"
            :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
            :has-error="v$.inboxId.$error"
            :message="v$.inboxId.$error ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.ERROR') : ''"
          />
        </div>

        <!-- HEADER media -->
        <div v-if="showMediaHeader" class="space-y-2">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.HEADER_SECTION') }}
          </h4>

          <label for="header-upload"
                 class="flex items-center justify-center gap-2 px-4 py-2 bg-n-alpha-3
                        border border-dashed border-n-slate-7 rounded-md text-sm cursor-pointer
                        hover:bg-n-alpha-4">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none"
                 viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M12 12V4m0 0l-4 4m4-4l4 4"/>
            </svg>
            <span>
              {{
                files.headerMediaName
                  || t(
                       selectedHeader
                         ? `CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_${selectedHeader.format}`
                         : 'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.HEADER_SECTION'
                     )
              }}
            </span>
          </label>
          <input id="header-upload" type="file"
                 :accept="headerAcceptMime(selectedHeader?.format)"
                 class="sr-only" @change="handleHeaderChange" />

          <p v-if="files.headerMediaName" class="text-xs mt-1">
            {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.FILE') }}{{ files.headerMediaName }}
          </p>
        </div>

        <!-- Scheduled date -->
        <Input v-model="state.scheduledAt" type="datetime-local"
               :min="new Date(Date.now() - new Date().getTimezoneOffset()*60000).toISOString().slice(0,16)"
               :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"/>
      </div>
    </div>

    <!-- Botones -->
    <div class="flex items-center justify-between pt-4">
      <Button variant="faded" color="slate"
              :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
              type="button" @click="handleCancel"/>
      <div class="flex gap-2">
        <Button
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.PREVIEW')"
          :disabled="isPreviewing || isPreviewDisabled"
          :is-loading="isPreviewing"
          type="button"
          @click="$emit('preview',{ /* ...datos para preview si se necesitan */ })"/>

        <Button
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
          :is-loading="isCreating"
          :disabled="isCreating || isCreateDisabled"
          type="button" @click="handleSubmit"/>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sr-only{
  position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;
  clip:rect(0,0,0,0);white-space:nowrap;border:0;
}
</style>
