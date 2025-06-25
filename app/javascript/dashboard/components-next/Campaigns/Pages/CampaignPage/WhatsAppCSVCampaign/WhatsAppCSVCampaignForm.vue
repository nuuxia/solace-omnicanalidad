<!-- WhatsAppCSVCampaignForm.vue -->
<script setup>
/* ─────────────────── imports ─────────────────── */
import { reactive, ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import Papa from 'papaparse';
import { toRefs } from 'vue';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

/* ─────────────────── emits / i18n ─────────────────── */
const emit = defineEmits(['submit', 'cancel', 'preview']);
const { t } = useI18n();
const K = 'CAMPAIGN.CSV.WHATSAPP.CREATE.FORM.'; // prefijo i18n

/* ─────────────────── store refs ─────────────────── */
const formState = {
  uiFlags: useMapGetter('campaignsWhatsApp/getUIFlags'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
};

/* ─────────────────── local state ─────────────────── */
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

const csvColumns = ref([]);
const bodyVariables = reactive([]); // [{sourceType,value}]
const buttonVariables = reactive([]); // [{type,dynamic,value,preview}]

/* ─────────────────── flags UI ─────────────────── */
const isCreating = computed(() => formState.uiFlags.value.isCreating);
const isPreviewing = computed(() => formState.uiFlags.value.isPreviewing);

/* ─────────────────── validations ─────────────────── */
const isPhoneValid = computed(() =>
  /^\+\d{6,15}$/.test(state.phoneNumber.trim())
);
const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  selectedWhatsAppTemplate: { required },
  contactsFile: { required },
  scheduledAt: { required },
};
const v$ = useVuelidate(rules, {
  ...toRefs(state), // ← mantiene la reactividad
  contactsFile: computed(() => files.contactsFile),
});

/* ─────────────────── helpers dependientes de inbox/template ─────────────────── */
const selectedInbox = computed(() =>
  formState.inboxes.value.find(inb => inb.id === state.inboxId)
);

const hasNamedPH = tpl =>
  tpl?.components?.some(c =>
    c?.text
      ?.match(/{{(.*?)}}/g)
      ?.some(ph => !/^\d+$/.test(ph.replace(/[{}]/g, '')))
  );

const whatsappTemplateOptions = computed(
  () =>
    selectedInbox.value?.message_templates
      ?.filter(tpl => !hasNamedPH(tpl))
      .map(tpl => ({ value: tpl.id, label: tpl.name })) ?? []
);

const selectedTemplate = computed(() =>
  selectedInbox.value?.message_templates?.find(
    tpl => tpl.id === state.selectedWhatsAppTemplate
  )
);

/* preview concatenado (HEADER + BODY) */
const templatePreview = computed(() => {
  if (!selectedTemplate.value) return '';
  return selectedTemplate.value.components
    .filter(comp => ['HEADER', 'BODY'].includes(comp.type) && comp.text)
    .map(comp => comp.text)
    .join('\n');
});

/* footer plain text */
const footerText = computed(
  () =>
    selectedTemplate.value?.components?.find(c => c.type === 'FOOTER')?.text ||
    ''
);

/* header helpers */
const selectedHeader = computed(
  () =>
    selectedTemplate.value?.components?.find(c => c.type === 'HEADER') ?? null
);
const showMediaHeader = computed(() =>
  ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(selectedHeader.value?.format || '')
);
const headerAcceptMime = fmt =>
  ({
    IMAGE: 'image/jpeg,image/png',
    VIDEO: 'video/mp4',
    DOCUMENT: 'application/pdf',
  })[fmt] || '*/*';

/* placeholders completos? */
const areBodyVarsFilled = computed(() =>
  bodyVariables.every(v => v.sourceType !== 'text' || v.value.trim())
);
const areButtonVarsFilled = computed(() =>
  buttonVariables.every(b => !b.dynamic || b.value.trim())
);

/* ─────────────────── disable flags ─────────────────── */
const isCreateDisabled = computed(
  () =>
    v$.value.title.$invalid ||
    v$.value.inboxId.$invalid ||
    v$.value.selectedWhatsAppTemplate.$invalid ||
    v$.value.contactsFile.$invalid ||
    v$.value.scheduledAt.$invalid ||
    !areBodyVarsFilled.value ||
    !areButtonVarsFilled.value ||
    !files.contactsFile ||
    (showMediaHeader.value && !files.headerMediaFile)
);
const isPreviewDisabled = computed(
  () =>
    !state.phoneNumber ||
    !isPhoneValid.value ||
    !state.inboxId ||
    !state.selectedWhatsAppTemplate ||
    !areBodyVarsFilled.value ||
    !areButtonVarsFilled.value ||
    (showMediaHeader.value && !files.headerMediaFile)
);

/* ─────────────────── CSV helpers ─────────────────── */
const validateHeaders = headers => {
  const lower = headers.map(h => h.trim().toLowerCase());
  const missing = ['phone_number', 'status'].filter(r => !lower.includes(r));
  return { valid: !missing.length, missing };
};

function handleContactsChange(e) {
  const file = e.target.files[0];
  if (!file) {
    files.contactsFile = null;
    files.contactsFileName = '';
    csvColumns.value = [];
    return;
  }
  if (!file.name.toLowerCase().endsWith('.csv')) {
    useAlert(t(`${K}FILE.INVALID_FORMAT`));
    return;
  }

  files.contactsFile = file;
  files.contactsFileName = file.name;

  const reader = new FileReader();
  reader.onload = ev => {
    const parsed = Papa.parse(ev.target.result, { header: true, preview: 1 });
    const { valid, missing } = validateHeaders(parsed.meta.fields || []);
    if (!valid) {
      useAlert(t(`${K}MISSING_COLUMNS`, { cols: missing.join(', ') }));
      files.contactsFile = null;
      files.contactsFileName = '';
      csvColumns.value = [];
      return;
    }
    csvColumns.value = parsed.meta.fields.filter(Boolean).map(h => h.trim());
  };
  reader.readAsText(file);
}

/* ─────────────────── header media file ─────────────────── */
function handleHeaderChange(e) {
  const f = e.target.files[0];
  if (f) {
    files.headerMediaFile = f;
    files.headerMediaName =
      f.name.length > 30 ? `${f.name.slice(0, 30)}…` : f.name;
  } else {
    files.headerMediaFile = null;
    files.headerMediaName = '';
  }
}

/* ─────────────────── parse placeholders ─────────────────── */
function parseTemplateVariables() {
  bodyVariables.splice(0);
  buttonVariables.splice(0);

  if (!selectedTemplate.value) return;

  /* BODY variables */
  const body = selectedTemplate.value.components.find(c => c.type === 'BODY');
  body?.text
    ?.match(/{{\d+}}/g)
    ?.forEach(() => bodyVariables.push({ sourceType: 'text', value: '' }));

  /* BUTTON variables + preview */
  const btnComp = selectedTemplate.value.components.find(
    c => c.type === 'BUTTONS'
  );
  btnComp?.buttons?.forEach(btn => {
    const hasPH = /{{\d+}}/.test(btn.url ?? btn.phone_number ?? '');
    if (btn.type === 'COPY_CODE') {
      buttonVariables.push({
        type: 'COPY_CODE',
        dynamic: true,
        value: '',
        preview: btn.text || 'Copy Code',
      });
    } else if (btn.type === 'URL' && hasPH) {
      buttonVariables.push({
        type: 'URL',
        dynamic: true,
        value: '',
        preview: btn.url,
      });
    } else if (btn.type === 'PHONE_NUMBER' && hasPH) {
      buttonVariables.push({
        type: 'PHONE_NUMBER',
        dynamic: true,
        value: '',
        preview: btn.phone_number,
      });
    }
  });
}

/* watchers */
watch(
  [
    () => state.selectedWhatsAppTemplate,
    () => state.inboxId,
    () => formState.inboxes.value,
  ],
  parseTemplateVariables,
  { immediate: true }
);

watch(
  () => ({
    ...state,
    contactsFile: files.contactsFile,
    headerMediaFile: files.headerMediaFile,
    bodyVars: bodyVariables.map(v => `${v.sourceType}:${v.value}`),
    buttonVars: buttonVariables.map(b => b.value),
  }),
  () => v$.value.$touch(),
  { deep: true }
);

/* helper para renderizar texto de preview sin usar regex en template */
function renderButtonPreview(raw) {
  if (!raw) return '';
  return raw.replace(/\{\{\d+\}\}/, '…');
}

/* helpers */
const toUTC = l => (l ? new Date(l).toISOString() : null);

/* reset & submit */
function resetForm() {
  Object.assign(state, initialState);
  Object.keys(files).forEach(k => (files[k] = k.includes('Name') ? '' : null));
  csvColumns.value = [];
  bodyVariables.splice(0);
  buttonVariables.splice(0);
}

async function handleSubmit() {
  if (!(await v$.value.$validate())) return;
  if (!areBodyVarsFilled.value)
    return useAlert(t(`${K}TEMPLATE.BODY.ERROR_PLACEHOLDERS`));
  if (!areButtonVarsFilled.value)
    return useAlert(t(`${K}TEMPLATE.BUTTONS.ERROR_EMPTY_URL`));

  const fd = new FormData();
  fd.append('title', state.title);
  fd.append('inbox_id', state.inboxId);
  fd.append('template', JSON.stringify(selectedTemplate.value));
  fd.append('scheduled_at', toUTC(state.scheduledAt));
  fd.append('csv_file', files.contactsFile);
  fd.append('original_csv_filename', files.contactsFileName);
  fd.append('body_variables', JSON.stringify(bodyVariables));
  fd.append('button_variables', JSON.stringify(buttonVariables));
  if (files.headerMediaFile)
    fd.append('headerMediaFile', files.headerMediaFile);

  emit('submit', fd);
  resetForm();
}

const handleCancel = () => emit('cancel');
const debugDisabled = computed(() => ({
  title: v$.value.title.$invalid,
  inbox: v$.value.inboxId.$invalid,
  template: v$.value.selectedWhatsAppTemplate.$invalid,
  contacts: v$.value.contactsFile.$invalid,
  scheduledAt: v$.value.scheduledAt.$invalid,
  bodyVars: !areBodyVarsFilled.value,
  buttonVars: !areButtonVarsFilled.value,
  csvMissing: !files.contactsFile,
  headerMiss: showMediaHeader.value && !files.headerMediaFile,
}));

watch(debugDisabled, val => console.table(val), { immediate: true });
</script>

<template>
  <div class="overflow-y-auto max-h-[80vh] p-6 space-y-6">
    <!-- 1. Archivo CSV -->
    <div class="space-y-1">
      <label class="block text-sm font-medium text-n-slate-12">
        {{ t(`${K}FILE.LABEL`) }}
      </label>

      <label
        for="contacts-upload"
        class="flex items-center justify-center gap-2 px-4 py-2 bg-n-alpha-3 border border-dashed border-n-slate-7 rounded-md text-sm cursor-pointer hover:bg-n-alpha-4"
      >
        <i class="i-lucide-upload w-4 h-4" />
        <span>{{ files.contactsFileName || t(`${K}FILE.CHOOSE`) }}</span>
      </label>

      <input
        id="contacts-upload"
        type="file"
        accept=".csv"
        class="sr-only"
        @change="handleContactsChange"
      />
      <p v-if="v$.contactsFile.$error" class="text-xs text-red-500 mt-1">
        {{ t(`${K}FILE.ERROR`) }}
      </p>
    </div>

    <!-- 2. Grid -->
    <div class="grid gap-6 md:grid-cols-2">
      <!-- ─────────── IZQUIERDA ─────────── -->
      <div class="space-y-6">
        <!-- Título -->
        <Input
          v-model="state.title"
          :label="t(`${K}TITLE.LABEL`)"
          :placeholder="t(`${K}TITLE.PLACEHOLDER`)"
          :message="v$.title.$error ? t(`${K}TITLE.ERROR`) : ''"
          :message-type="v$.title.$error ? 'error' : 'info'"
        />

        <!-- Plantilla -->
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t(`${K}WHATSAPP_TEMPLATE.LABEL`) }}
          </label>
          <ComboBox
            v-model="state.selectedWhatsAppTemplate"
            :options="whatsappTemplateOptions"
            :placeholder="t(`${K}WHATSAPP_TEMPLATE.PLACEHOLDER`)"
            :has-error="v$.selectedWhatsAppTemplate.$error"
            :message="
              v$.selectedWhatsAppTemplate.$error
                ? t(`${K}WHATSAPP_TEMPLATE.ERROR`)
                : ''
            "
            :disabled="!state.inboxId"
          />
        </div>

        <!-- Preview HEADER+BODY -->
        <div v-if="templatePreview">
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ t(`${K}TEMPLATE.PREVIEW_TITLE`) }}
          </p>
          <pre
            class="whitespace-pre-line rounded-lg border border-n-slate-7 p-3 text-sm text-n-slate-11 overflow-x-auto"
            >{{ templatePreview }}</pre
          >
        </div>

        <!-- Preview FOOTER -->
        <div
          v-if="footerText"
          class="rounded-lg border border-n-slate-7 p-3 bg-n-alpha-2"
        >
          <h4 class="text-sm font-semibold text-n-slate-12 mb-2">
            {{ t(`${K}TEMPLATE.FOOTER.HEADER_SECTION`) }}
          </h4>
          <div class="flex items-start gap-2">
            <p class="whitespace-pre-line text-sm text-n-slate-11">
              {{ footerText }}
            </p>
          </div>
        </div>

        <!-- Variables BODY -->
        <div v-if="bodyVariables.length" class="space-y-3">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t(`${K}TEMPLATE.BODY.HEADER_SECTION`) }}
          </h4>

          <div v-for="(v, idx) in bodyVariables" :key="idx">
            <div
              class="flex items-center gap-2 bg-n-alpha-3 border border-n-slate-8 rounded-md p-3"
            >
              <span
                class="w-6 h-6 flex items-center justify-center rounded-full text-xs font-semibold text-n-slate-11 bg-n-solid-3"
              >
                {{ idx + 1 }}
              </span>

              <ComboBox
                v-model="v.sourceType"
                class="md:w-1/3 flex-shrink-0"
                :options="[
                  { value: 'text', label: 'Text' },
                  ...csvColumns.map(c => ({ value: c, label: c })),
                ]"
              />

              <input
                v-if="v.sourceType === 'text'"
                v-model="v.value"
                class="flex-1 text-sm border border-n-slate-7 rounded px-2 py-1 bg-transparent placeholder-n-slate-11 focus:outline-none"
                :placeholder="t(`${K}TEMPLATE.BODY.VARIABLE_PLACE_HOLDER`)"
              />
            </div>
          </div>
        </div>

        <!-- Teléfono para preview -->
        <Input
          v-model="state.phoneNumber"
          :label="t(`${K}PREVIEW_SECTION.PHONE_LABEL`)"
          :placeholder="t(`${K}PREVIEW_SECTION.PLACEHOLDER`)"
          :message="
            state.phoneNumber && !isPhoneValid
              ? t(`${K}PREVIEW_SECTION.ERROR_PLUS`)
              : ''
          "
          :message-type="state.phoneNumber && !isPhoneValid ? 'error' : 'info'"
        />
      </div>

      <!-- ─────────── DERECHA ─────────── -->
      <div class="space-y-6">
        <!-- Inbox -->
        <div>
          <label class="block mb-1 text-sm font-medium text-n-slate-12">
            {{ t(`${K}INBOX.LABEL`) }}
          </label>
          <ComboBox
            v-model="state.inboxId"
            :options="
              formState.inboxes.value?.map(i => ({
                value: i.id,
                label: i.name,
              })) ?? []
            "
            :placeholder="t(`${K}INBOX.PLACEHOLDER`)"
            :has-error="v$.inboxId.$error"
            :message="v$.inboxId.$error ? t(`${K}INBOX.ERROR`) : ''"
          />
        </div>

        <!-- Header media -->
        <div v-if="showMediaHeader" class="space-y-2">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t(`${K}TEMPLATE.MEDIA.HEADER_SECTION`) }}
          </h4>
          <label
            for="header-upload"
            class="flex items-center justify-center gap-2 px-4 py-2 bg-n-alpha-3 border border-dashed border-n-slate-7 rounded-md text-sm cursor-pointer hover:bg-n-alpha-4"
          >
            <i class="i-lucide-upload w-4 h-4" />
            <span>
              {{
                files.headerMediaName ||
                t(
                  {
                    IMAGE: `${K}TEMPLATE.MEDIA.UPLOAD_IMAGE`,
                    VIDEO: `${K}TEMPLATE.MEDIA.UPLOAD_VIDEO`,
                    DOCUMENT: `${K}TEMPLATE.MEDIA.UPLOAD_DOCUMENT`,
                  }[selectedHeader.format]
                )
              }}
            </span>
          </label>
          <input
            id="header-upload"
            type="file"
            class="sr-only"
            :accept="headerAcceptMime(selectedHeader.format)"
            @change="handleHeaderChange"
          />
        </div>

        <!-- Programación -->
        <Input
          v-model="state.scheduledAt"
          type="datetime-local"
          :min="
            new Date(Date.now() - new Date().getTimezoneOffset() * 60000)
              .toISOString()
              .slice(0, 16)
          "
          :label="t(`${K}SCHEDULED_AT.LABEL`)"
        />

        <!-- Variables BOTONES -->
        <div v-if="buttonVariables.length" class="space-y-3">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t(`${K}TEMPLATE.BUTTONS.HEADER_SECTION`) }}
          </h4>

          <div
            v-for="(btn, idx) in buttonVariables"
            :key="idx"
            class="flex flex-col gap-2 bg-n-alpha-3 border border-n-slate-8 rounded-md p-3"
          >
            <!-- preview del botón -->
            <p class="text-xs text-n-slate-11">
              {{ t(`${K}TEMPLATE.BUTTONS.PREVIEW_LABEL`) }} {{ idx + 1 }}:
              <span class="font-medium">{{
                renderButtonPreview(btn.preview)
              }}</span>
            </p>

            <!-- input de variable -->
            <input
              v-model="btn.value"
              class="border border-n-slate-7 rounded px-2 py-1 text-sm"
              :placeholder="t(`${K}TEMPLATE.BUTTONS.VARIABLE_PLACE_HOLDER`)"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- 3. Botones principales -->
    <div class="flex items-center justify-between pt-4">
      <Button
        variant="faded"
        color="slate"
        :label="t('CAMPAIGN.CSV.WHATSAPP.CREATE.CANCEL_BUTTON_TEXT')"
        @click="handleCancel"
      />

      <div class="flex gap-2">
        <Button
          :label="t(`${K}PREVIEW_SECTION.BUTTON_LABEL`)"
          :disabled="isPreviewing || isPreviewDisabled"
          :is-loading="isPreviewing"
          @click="$emit('preview', {})"
        />
        <Button
          :label="t(`${K}BUTTONS.CREATE`)"
          :disabled="isCreating || isCreateDisabled"
          :is-loading="isCreating"
          @click="handleSubmit"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
  border: 0;
}
</style>
