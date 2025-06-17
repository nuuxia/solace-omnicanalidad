<script setup>
/* ─────────────── imports ─────────────── */
import { reactive, ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, helpers } from '@vuelidate/validators';
import Papa from 'papaparse';

import Input    from 'dashboard/components-next/input/Input.vue';
import Button   from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert }     from 'dashboard/composables';

/* ─────────────── emits / i18n ─────────────── */
const emit = defineEmits(['submit', 'cancel', 'preview']);
const { t } = useI18n();

/* ─────────────── global store refs ─────────────── */
const formState = {
  uiFlags : useMapGetter('campaignsWhatsApp/getUIFlags'),
  inboxes : useMapGetter('inboxes/getWhatsAppInboxes'),
};

const safeUIFlags = computed(() => formState.uiFlags?.value ?? {
  isCreating   : false,
  isPreviewing : false,
  previewError : null,
});

/* ─────────────── local state ─────────────── */
const initialState = {
  title                   : '',
  inboxId                 : null,
  selectedWhatsAppTemplate: null,
  scheduledAt             : null,
  phoneNumber             : '',
};
const state = reactive({ ...initialState });

const files = reactive({
  contactsFile     : null,
  contactsFileName : '',
  headerMediaFile  : null,
  headerMediaName  : '',
});

const csvColumns      = ref([]);
const bodyVariables   = reactive([]);
const buttonVariables = reactive([]);

/* flags UI */
const isCreating   = computed(() => safeUIFlags.value.isCreating);
const isPreviewing = computed(() => safeUIFlags.value.isPreviewing);

/* ─────────────── validation ─────────────── */
const startsWithPlus = helpers.withMessage(
  t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_PLUS'),
  v => !v || /^\+\d{6,15}$/.test(v)
);

const rules = {
  title                  : { required, minLength: minLength(1) },
  inboxId                : { required },
  selectedWhatsAppTemplate: { required },
  contactsFile           : { required },
  scheduledAt            : { required },
  phoneNumber            : { startsWithPlus },
};

const v$ = useVuelidate(rules, {
  ...state,
  contactsFile : computed(() => files.contactsFile),
});

/* ─────────────── helpers computados ─────────────── */
const selectedInbox = computed(() =>
  formState.inboxes.value.find(inb => inb.id === state.inboxId)
);

const hasNamedPlaceholders = tpl =>
  tpl?.components?.some(comp =>
    comp.text?.match(/{{(.*?)}}/g)?.some(ph => !/^\d+$/.test(ph.replace(/\{|}/g, '')))
  );

const whatsappTemplateOptions = computed(
  () =>
    selectedInbox.value?.message_templates
      ?.filter(tpl => !hasNamedPlaceholders(tpl))
      .map(tpl => ({ value: tpl.id, label: tpl.name })) ?? []
);

const selectedTemplate = computed(() =>
  selectedInbox.value?.message_templates?.find(
    tpl => tpl.id === state.selectedWhatsAppTemplate
  )
);

/* Preview vacío o con HEADER/BODY/FOOTER concatenados */
const templatePreview = computed(() => {
  if (!selectedTemplate.value) return '';
  return selectedTemplate.value.components
    .filter(c => ['HEADER', 'BODY', 'FOOTER'].includes(c.type) && c.text)
    .map(c => c.text)
    .join('\n');
});

const selectedHeader = computed(
  () => selectedTemplate.value?.components?.find(c => c.type === 'HEADER') ?? null
);

const showMediaHeader = computed(() =>
  ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(selectedHeader.value?.format || '')
);

const headerAcceptMime = fmt =>
  ({
    IMAGE   : 'image/jpeg,image/png',
    VIDEO   : 'video/mp4',
    DOCUMENT: 'application/pdf',
  })[fmt] || '*/*';

const areBodyVarsFilled = computed(() =>
  bodyVariables.every(v => v.sourceType !== 'text' || v.value.trim())
);
const areButtonVarsFilled = computed(() =>
  buttonVariables.every(b => !b.dynamic || b.value.trim())
);

const isCreateDisabled = computed(
  () =>
    v$.value.$invalid          ||
    !areBodyVarsFilled.value   ||
    !areButtonVarsFilled.value ||
    !files.contactsFile        ||
    (showMediaHeader.value && !files.headerMediaFile)
);

const isPreviewDisabled = computed(
  () =>
    v$.value.phoneNumber.$invalid  ||
    !state.phoneNumber             ||
    !state.inboxId                 ||
    !state.selectedWhatsAppTemplate||
    !areBodyVarsFilled.value       ||
    !areButtonVarsFilled.value     ||
    (showMediaHeader.value && !files.headerMediaFile)
);

/* ─────────────── CSV helpers ─────────────── */
const validateHeaders = headers => {
  const lower   = headers.map(h => h.trim().toLowerCase());
  const missing = ['phone_number', 'status'].filter(r => !lower.includes(r));
  return { valid: !missing.length, missing };
};

const processHeaders = headers => {
  const { valid, missing } = validateHeaders(headers);
  if (!valid) {
    useAlert(
      t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.MISSING_COLUMNS', { cols: missing.join(', ') })
    );
    files.contactsFile     = null;
    files.contactsFileName = '';
    csvColumns.value       = [];
    return;
  }
  csvColumns.value = headers.filter(Boolean).map(h => h.trim());
};

function handleContactsChange (e) {
  const file = e.target.files[0];
  if (!file) {
    files.contactsFile     = null;
    files.contactsFileName = '';
    csvColumns.value       = [];
    return;
  }
  if (!file.name.toLowerCase().endsWith('.csv')) {
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.FILE.INVALID_FORMAT'));
    return;
  }

  files.contactsFile     = file;
  files.contactsFileName = file.name;

  const reader = new FileReader();
  reader.onload = evt => {
    const res = Papa.parse(evt.target.result, { header: true, preview: 1 });
    processHeaders(res.meta.fields || []);
  };
  reader.readAsText(file);
}

/* HEADER media */
function handleHeaderChange (e) {
  const f = e.target.files[0];
  files.headerMediaFile = f ?? null;

  if (!f) { files.headerMediaName = ''; return; }

  const maxLen          = 30;
  files.headerMediaName = f.name.length > maxLen
    ? `${f.name.slice(0, maxLen)}…`
    : f.name;
}

/* ─────────────── template placeholder parser ─────────────── */
function parseTemplateVars () {
  bodyVariables.splice(0);
  buttonVariables.splice(0);

  if (!selectedTemplate.value) return;

  const body = selectedTemplate.value.components.find(c => c.type === 'BODY');
  body?.text?.match(/{{(.*?)}}/g)?.forEach(() =>
    bodyVariables.push({ sourceType: 'text', value: '' })
  );

  const btnComp = selectedTemplate.value.components.find(c => c.type === 'BUTTONS');
  btnComp?.buttons?.forEach(btn => {
    if (btn.type === 'COPY_CODE')
      buttonVariables.push({ type: 'COPY_CODE', dynamic: true, value: '' });
    else if (btn.type === 'URL' && /{{(.*?)}}/.test(btn.url))
      buttonVariables.push({ type: 'URL', dynamic: true, value: '' });
    else if (btn.type === 'PHONE_NUMBER' && /{{(.*?)}}/.test(btn.phone_number))
      buttonVariables.push({ type: 'PHONE_NUMBER', dynamic: true, value: '' });
  });
}
watch(() => state.selectedWhatsAppTemplate, parseTemplateVars, { immediate: true });

/* ─────────────── util helpers ─────────────── */
const uploadMediaI18nKey = computed(() => {
  switch (selectedHeader.value?.format) {
    case 'IMAGE'   : return 'CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_IMAGE';
    case 'VIDEO'   : return 'CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_VIDEO';
    case 'DOCUMENT': return 'CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.UPLOAD_DOCUMENT';
    default        : return 'CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.HEADER_SECTION';
  }
});

const toUTC = local => (local ? new Date(local).toISOString() : null);

/* ─────────────── reset & submit ─────────────── */
function resetForm () {
  Object.assign(state, initialState);
  for (const k in files) { files[k] = k.includes('Name') ? '' : null; }
  csvColumns.value = [];
  bodyVariables.splice(0);
  buttonVariables.splice(0);
}

async function handleSubmit () {
  if (!(await v$.value.$validate())) return;

  if (!areBodyVarsFilled.value) {
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.ERROR_PLACEHOLDERS'));
    return;
  }
  if (!areButtonVarsFilled.value) {
    useAlert(t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.BUTTONS.ERROR_EMPTY_URL'));
    return;
  }

  const fd = new FormData();
  fd.append('title',            state.title);
  fd.append('inbox_id',         state.inboxId);
  fd.append('template',         JSON.stringify(selectedTemplate.value));
  fd.append('scheduled_at',     toUTC(state.scheduledAt));
  fd.append('contacts_file',    files.contactsFile);
  fd.append('body_variables',   JSON.stringify(bodyVariables));
  fd.append('button_variables', JSON.stringify(buttonVariables));
  if (files.headerMediaFile) fd.append('headerMediaFile', files.headerMediaFile);

  emit('submit', fd);
  resetForm();
}

const handleCancel = () => emit('cancel');
</script>

<template>
  <div class="overflow-y-auto max-h-[80vh] p-6 space-y-6">
    <!-- Archivo CSV -->
    <div class="space-y-1">
      <label class="block text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.FILE.LABEL') }}
      </label>

      <label
        for="contacts-upload"
        class="flex items-center justify-center gap-2 px-4 py-2 bg-n-alpha-3 border border-dashed border-n-slate-7 rounded-md text-sm cursor-pointer hover:bg-n-alpha-4"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M12 12V4m0 0l-4 4m4-4l4 4"/>
        </svg>
        <span>{{ files.contactsFileName || t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.FILE.CHOOSE') }}</span>
      </label>

      <input id="contacts-upload" type="file" accept=".csv" class="sr-only" @change="handleContactsChange" />

      <p v-if="v$.contactsFile.$error" class="text-xs text-red-500 mt-1">
        {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.FILE.ERROR') }}
      </p>
    </div>

    <!-- GRID de 2 columnas -->
    <div class="grid gap-6 md:grid-cols-2">
      <!-- COL A -->
      <div class="space-y-6">
        <!-- Título -->
        <Input
          v-model="state.title"
          :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
          :placeholder="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
          :message="v$.title.$error ? t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TITLE.ERROR') : ''"
          :message-type="v$.title.$error ? 'error' : 'info'"
        />

        <!-- Template selector -->
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.LABEL') }}
          </label>
          <ComboBox
            v-model="state.selectedWhatsAppTemplate"
            :options="whatsappTemplateOptions"
            :placeholder="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.PLACEHOLDER')"
            :has-error="v$.selectedWhatsAppTemplate.$error"
            :message="v$.selectedWhatsAppTemplate.$error ? t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.WHATSAPP_TEMPLATE.ERROR') : ''"
            :disabled="!state.inboxId"
          />
        </div>

        <!-- Preview texto plantilla -->
        <div v-if="templatePreview">
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.PREVIEW_TITLE') }}
          </p>
          <pre
            class="whitespace-pre-line rounded-lg border border-n-slate-7 p-3 text-sm text-n-slate-11 overflow-x-auto"
          >{{ templatePreview }}</pre>
        </div>

        <!-- Variables -->
        <div v-if="bodyVariables.length" class="space-y-3">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.HEADER_SECTION') }}
          </h4>

          <div v-for="(v, idx) in bodyVariables" :key="idx">
            <div class="flex items-center gap-2 bg-n-alpha-3 border border-n-slate-8 rounded-md p-3">
              <!-- Número centrado -->
              <span
                class="w-6 h-6 flex items-center justify-center rounded-full text-xs font-semibold text-n-slate-11 bg-n-solid-3"
              >
                {{ idx + 1 }}
              </span>

              <ComboBox
                v-model="v.sourceType"
                :options="[{ value: 'text', label: 'Text' }, ...csvColumns.map(col => ({ value: col, label: col }))]"
                class="md:w-1/3 flex-shrink-0"
              />

              <input
                v-if="v.sourceType === 'text'"
                v-model="v.value"
                class="flex-1 text-sm border border-n-slate-7 rounded px-2 py-1 bg-transparent placeholder-n-slate-11 focus:outline-none"
                :placeholder="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.BODY.VARIABLE_PLACE_HOLDER')"
              />
            </div>
          </div>
        </div>

        <!-- Teléfono para preview -->
        <Input
          v-model="state.phoneNumber"
          :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PHONE_LABEL')"
          :placeholder="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.PLACEHOLDER')"
          :message="v$.phoneNumber.$error ? t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.ERROR_PLUS') : ''"
          :message-type="v$.phoneNumber.$error ? 'error' : 'info'"
        />
      </div>

      <!-- COL B -->
      <div class="space-y-6">
        <!-- Inbox -->
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
          </label>
          <ComboBox
            v-model="state.inboxId"
            :options="formState.inboxes.value?.map(inb => ({ value: inb.id, label: inb.name })) ?? []"
            :placeholder="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
            :has-error="v$.inboxId.$error"
            :message="v$.inboxId.$error ? t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.INBOX.ERROR') : ''"
          />
        </div>

        <!-- Header media -->
        <div v-if="showMediaHeader" class="space-y-2">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.TEMPLATE.MEDIA.HEADER_SECTION') }}
          </h4>

          <label
            for="header-upload"
            class="flex items-center justify-center gap-2 px-4 py-2 bg-n-alpha-3 border border-dashed border-n-slate-7 rounded-md text-sm cursor-pointer hover:bg-n-alpha-4"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2M12 12V4m0 0l-4 4m4-4l4 4"/>
            </svg>
            <span>{{ files.headerMediaName || t(uploadMediaI18nKey) }}</span>
          </label>
          <input
            id="header-upload"
            type="file"
            class="sr-only"
            :accept="headerAcceptMime(selectedHeader.format)"
            @change="handleHeaderChange"
          />
        </div>

        <!-- Fecha / hora -->
        <Input
          v-model="state.scheduledAt"
          type="datetime-local"
          :min="new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0,16)"
          :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
        />
      </div>
    </div>

    <!-- Botones -->
    <div class="flex items-center justify-between pt-4">
      <Button
        variant="faded"
        color="slate"
        :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        @click="handleCancel"
      />

      <div class="flex gap-2">
        <Button
          :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.PREVIEW_SECTION.BUTTON_LABEL')"
          :disabled="isPreviewing || isPreviewDisabled"
          :is-loading="isPreviewing"
          @click="$emit('preview', {})"
        />
        <Button
          :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
          :disabled="isCreating || isCreateDisabled"
          :is-loading="isCreating"
          @click="handleSubmit"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.sr-only{
  position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;
  clip:rect(0 0 0 0);white-space:nowrap;border:0;
}
</style>
