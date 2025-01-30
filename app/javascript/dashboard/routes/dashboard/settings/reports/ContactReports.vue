<script>
import WootReports from './components/WootReports.vue';

export default {
  components: {
    WootReports,
  },
};
</script>

<template>
  <WootReports
    key="contact-reports"
    type="contact"
    getter-key="contacts/getContacts"
    action-key="contacts/get"
    :download-button-label="$t('COMPANY_REPORTS.DOWNLOAD_COMPANY_REPORTS')"
  />
</template>
