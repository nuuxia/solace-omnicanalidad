<script>
import mercadoLibreClient from '../../../../../api/channel/mercadoLibreClient';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  data() {
    return { isRequestingAuthorization: false };
  },
  components :{
    NextButton,
  },
  methods: {
    async requestAuthorization() {
      try {
        this.isRequestingAuthorization = true;
        const response = await mercadoLibreClient.generateAuthorization();
        const {
          data: { authUrl },
        } = response;
        window.location.href = authUrl;
      } catch (error) {
        this.showAlert(
          this.$t('INBOX_MGMT.ADD.MERCADO_LIBRE_CHANNEL.ERROR_MESSAGE')
        );
      } finally {
        this.isRequestingAuthorization = false;
      }
    },
  },
};
</script>

<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <div class="login-init h-full text-center">
      <form @submit.prevent="requestAuthorization">
        <NextButton
        type="submit"
        :loading="isRequestingAuthorization"
      >
        Sign in with Mercado Libre
      </NextButton>
      </form>
      <p>{{ $t('INBOX_MGMT.ADD.MERCADO_LIBRE_CHANNEL.HELP') }}</p>
    </div>
  </div>
</template>

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
