<script>
export default {
  name: 'AutomationActionAlertInput',
  props: {
    modelValue: {
      type: Object,
      required: true,
    },
  },
  emits: ['update:modelValue'],
  data() {
    return {
      selectedInboxId: null,
      selectedTemplateId: null,
      phoneNumber: '',
    };
  },
  mounted() {
    const { inbox_id: inboxId, template_id: templateId, phone_number: phoneNumber } = this.modelValue;
    this.selectedInboxId = inboxId;
    this.selectedTemplateId = templateId;
    this.phoneNumber = phoneNumber;
  },
  computed: {
    whatsappInboxes() {
      return this.$store.getters['inboxes/getWhatsAppInboxes'] || [];
    },
    availableTemplates() {
      if (!this.selectedInboxId) return [];
      const selectedInbox = this.whatsappInboxes.find(
        (inbox) => inbox.id === this.selectedInboxId
      );
      return selectedInbox?.message_templates || [];
    },
  },
  methods: {
    updateValue() {
      this.$emit('update:modelValue', {
        inbox_id: this.selectedInboxId,
        template_id: this.selectedTemplateId,
        phone_number: this.phoneNumber,
      });
    },
  },
};
</script>

<template>
  <div class="automation-action-alert-input">
    <!-- WhatsApp Inbox Selection -->
    <label for="whatsappInbox" class="form-label mt-4">Select WhatsApp Inbox:</label>
    <select
      id="whatsappInbox"
      class="form-select"
      v-model="selectedInboxId"
      @change="updateValue"
    >
      <option value="" disabled>Select an inbox</option>
      <option v-for="inbox in whatsappInboxes" :key="inbox.id" :value="inbox.id">
        {{ inbox.name }}
      </option>
    </select>
    <small v-if="!whatsappInboxes.length" class="text-muted">
      No WhatsApp inboxes available.
    </small>

    <!-- Template Selection -->
    <label for="template" class="form-label">Select Template:</label>
    <select
      id="template"
      class="form-select"
      v-model="selectedTemplateId"
      @change="updateValue"
      :disabled="!selectedInboxId || !availableTemplates.length"
    >
      <option value="" disabled>Select a template</option>
      <option v-for="template in availableTemplates" :key="template.id" :value="template.id">
        {{ template.name }}
      </option>
    </select>
    <small v-if="!selectedInboxId" class="text-muted">
      Select a WhatsApp inbox to view templates.
    </small>
    <small v-if="selectedInboxId && !availableTemplates.length" class="text-muted">
      No templates available for the selected inbox.
    </small>

    <!-- Phone Number Input -->
    <label for="phoneNumber" class="form-label">Phone Number:</label>
    <input
      id="phoneNumber"
      type="tel"
      class="form-control"
      v-model="phoneNumber"
      @input="updateValue"
      placeholder="Enter phone number (e.g., +1234567890)"
    />
    <small class="text-muted">
      Please enter a valid international phone number starting with +.
    </small>
  </div>
</template>

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

.text-muted {
  font-size: 0.875rem;
  color: #6b7280;
}
</style>
