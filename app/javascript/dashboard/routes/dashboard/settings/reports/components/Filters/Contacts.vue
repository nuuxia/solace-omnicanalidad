<script>
import { mapGetters } from 'vuex';

export default {
  name: 'ReportsFiltersContacts',
  emits: ['contactFilterSelection'],
  data() {
    return {
      selectedOption: null,
    };
  },
  computed: {
    ...mapGetters({
      options: 'contacts/getContacts',
    }),
  },
  mounted() {
    this.$store.dispatch('contacts/get');
  },
  methods: {
    handleInput() {
      this.$emit('contactFilterSelection', this.selectedOption);
    },
  },
};
</script>

<template>
  <div class="multiselect-wrap--small">
    <multiselect
      v-model="selectedOption"
      class="no-margin"
      :placeholder="$t('COMPANY_REPORTS.FILTER_DROPDOWN_LABEL')"
      label="name"
      track-by="id"
      :options="options"
      :option-height="24"
      :show-labels="false"
      @update:model-value="handleInput"
    />
  </div>
</template>
