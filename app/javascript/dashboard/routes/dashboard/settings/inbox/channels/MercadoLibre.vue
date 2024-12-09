<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <div class="login-init h-full text-center">
      <form @submit.prevent="requestAuthorization">
        <woot-submit-button
          icon=""
          button-text="Sign in with Mercado Libre"
          type="submit"
          :loading="isRequestingAuthorization"
        />
      </form>
      <p>{{ $t('INBOX_MGMT.ADD.MERCADO_LIBRE_CHANNEL.HELP') }}</p>
    </div>
  </div>
</template>
<script>
import mercadoLibreClient from '../../../../../api/channel/mercadoLibreClient';
export default {
  data() {
    return { isRequestingAuthorization: false };
  },
  methods: {
    async requestAuthorization() {
      try {
        this.isRequestingAuthorization = true;
        const response = await mercadoLibreClient.generateAuthorization();
        const { data: { authUrl } } = response;
        window.location.href = authUrl;
      } catch (error) {
        this.showAlert(this.$t('INBOX_MGMT.ADD.MERCADO_LIBRE_CHANNEL.ERROR_MESSAGE'));
      } finally {
        this.isRequestingAuthorization = false;
      }
    },
  },
};
</script>
<style scoped lang="scss">
.login-init {
  @apply pt-[30%] text-center;
  p {
    @apply p-6;
  }
  > a > img {
    @apply w-60;
  }
}
</style>
