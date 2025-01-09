<template>
  <div class="automation-action-alert-input">
    <!-- WhatsApp Inbox Selection -->
    <label for="whatsappInbox" class="form-label mt-4">Select WhatsApp Inbox:</label>
    <select
      id="whatsappInbox"
      class="form-select"
      v-model="localValue.inboxId"
      @change="emitValue"
    >
      <option value="" disabled>Select an inbox</option>
      <option v-for="inbox in whatsappInboxes" :key="inbox.id" :value="inbox.id">
        {{ inbox.name }}
      </option>
    </select>

    <!-- Template Selection -->
    <label for="template" class="form-label">Select Template:</label>
    <select
      id="template"
      class="form-select"
      v-model="localValue.templateId"
      @change="emitValue"
    >
      <option value="" disabled>Select a template</option>
      <option v-for="template in availableTemplates" :key="template.id" :value="template.id">
        {{ template.name }}
      </option>
    </select>

    <!-- Phone Number Input -->
    <label for="phoneNumber" class="form-label">Phone Number:</label>
    <input
      id="phoneNumber"
      type="tel"
      class="form-control"
      v-model="localValue.phoneNumber"
      @input="emitValue"
      placeholder="Enter phone number (e.g., +1234567890)"
    />
  </div>
</template>

<script>
import { useMapGetter } from 'dashboard/composables/store';

export default {
  name: 'AutomationActionAlertInput',
  props: {
    modelValue: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      localValue: { ...this.modelValue },
    };
  },
  computed: {
    whatsappInboxes() {
      return this.$store.getters['inboxes/getWhatsAppInboxes'] || [];
    },
    availableTemplates() {
      const selectedInbox = this.whatsappInboxes.find(
        (inbox) => inbox.id === this.localValue.inboxId
      );
      return selectedInbox?.message_templates || [];
    },
  },
  watch: {
    modelValue: {
      handler(newValue) {
        this.localValue = { ...newValue };
      },
      deep: true,
    },
  },
  methods: {
    emitValue() {
      this.$emit('update:modelValue', this.localValue);
    },
  },
};
</script>

<style scoped>
.automation-action-alert-input {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  max-width: 400px;
  margin: auto;
}

.form-label {
  font-weight: bold;
  color: #374151;
}

.form-select,
.form-control {
  padding: 0.5rem;
  font-size: 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
}

.form-select:focus,
.form-control:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
}
</style>
