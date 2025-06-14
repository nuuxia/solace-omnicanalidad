<script>
import PageHeader from '../../SettingsSubPageHeader.vue';
import Twilio from './Twilio.vue';
import ThreeSixtyDialogWhatsapp from './360DialogWhatsapp.vue';
import CloudWhatsapp from './CloudWhatsapp.vue';
import WhatsappChannel from '../../../../../api/whatsappChannel';
import router from '../../../../index';

export default {
  components: {
    PageHeader,
    Twilio,
    ThreeSixtyDialogWhatsapp,
    CloudWhatsapp,
  },
  data() {
    return {
      provider: 'whatsapp_cloud',
      fbScriptLoaded: false,
      isFacebookLoading: false,
    };
  },
  mounted() {
    // ---------------------------------------------------
    // Meta Embedded Signup – Version 3 (sessionInfo v3)
    // ---------------------------------------------------
    //  * Uses Graph API v22.0 and Embedded-Signup v3
    //  * Credentials supplied by user (appId & configId)
    //  * Supports onboarding of WA Business App numbers (coexistence)

    const appId = 623812436966102; // <- provided by user
    const graphApiVersion = 'v22.0';

    const fbScript = document.createElement('script');
    fbScript.async = true;
    fbScript.defer = true;
    fbScript.crossorigin = 'anonymous';
    fbScript.src = 'https://connect.facebook.net/en_US/sdk.js';

    fbScript.onload = () => {
      window.fbAsyncInit = () => {
        FB.init({
          appId,
          xfbml: true,
          cookie: true,
          version: graphApiVersion,
        });
      };

      window.addEventListener('message', async event => {
        if (
          event.origin !== 'https://www.facebook.com' &&
          event.origin !== 'https://web.facebook.com'
        ) {
          this.isFacebookLoading = false;
          return;
        }

        let eventData;
        try {
          eventData = JSON.parse(event.data);
        } catch (err) {
          console.error('Error parsing ES message:', err);
          return;
        }

        if (eventData.type !== 'WA_EMBEDDED_SIGNUP') return;

        if (eventData.event === 'CANCEL') {
          this.isFacebookLoading = false;
          return;
        }

        const FINISH_EVENTS = [
          'FINISH',
          'FINISH_ONLY_WABA',
          'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING',
        ];

        if (!FINISH_EVENTS.includes(eventData.event)) {
          console.warn('Unhandled ES event', eventData.event);
          this.isFacebookLoading = false;
          return;
        }

        const payload = { waba_id: eventData.data.waba_id };
        if (eventData.data.phone_number_id) {
          payload.phone_number_id = eventData.data.phone_number_id;
        }

        try {
          this.isFacebookLoading = true;
          const response = await this.createWhatsappChannel(payload);
          if (response?.inbox_id) {
            await this.navigateToInboxSettings(response.inbox_id);
          }
        } catch (error) {
          console.error('Error calling WhatsappChannel.automatedSignup:', error);
        } finally {
          this.isFacebookLoading = false;
        }
      });

      this.fbScriptLoaded = true;
    };

    document.body.appendChild(fbScript);
  },
  methods: {
    async createWhatsappChannel(payload) {
      try {
        const response = await WhatsappChannel.automatedSignup(payload);
        return response.data;
      } catch (error) {
        console.error('Error creating WhatsApp channel:', error);
        throw error;
      }
    },
    async navigateToInboxSettings(inboxId) {
      try {
        await router.push({
          name: 'settings_inbox_show',
          params: {
            accountId: this.$route.params.accountId,
            inboxId: inboxId.toString(),
          },
        });
      } catch (error) {
        console.error('Navigation error:', error);
      } finally {
        this.isFacebookLoading = false;
      }
    },
    launchWhatsAppSignup() {
      if (typeof FB === 'undefined') {
        console.error('FB SDK is not loaded yet.');
        return;
      }

      const configId = 3902798696627928; // <- provided by user

      const width = Math.min(600, window.innerWidth - 40);
      const height = Math.min(700, window.innerHeight - 40);
      const left = Math.round((window.innerWidth - width) / 2);
      const top = Math.round((window.innerHeight - height) / 2);

      this.isFacebookLoading = true;

      FB.login(
        () => {}, // FB returns data via postMessage
        {
          config_id: configId,
          auth_type: 'rerequest',
          response_type: 'code',
          override_default_response_type: true,
          display: 'popup',
          extras: {
            setup: {},
            featureType: 'whatsapp_business_app_onboarding',
            sessionInfoVersion: '3',
          },
          width,
          height,
          window_features: [
            `width=${width}`,
            `height=${height}`,
            `left=${left}`,
            `top=${top}`,
            'status=1',
            'toolbar=0',
            'menubar=0',
            'resizable=1',
            'scrollbars=1',
          ].join(','),
        },
      );
    },
  },
};
</script>

<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0 h-[1100px]"
  >
    <p class="mb-6 text-sm text-gray-500">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP.CHOOSE_METHOD') }}
    </p>

    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%] mb-4">
      <h2 class="text-xl font-semibold mb-1">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.AUTOMATED_TITLE') }}
      </h2>
      <p class="text-sm text-gray-500 mb-4">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.AUTOMATED_DESC') }}
      </p>
    </div>

    <div class="flex gap-4 mb-6">
      <button
        type="button"
        :disabled="!fbScriptLoaded || isFacebookLoading"
        class="facebook-login-button inline-flex items-center justify-center"
        @click="launchWhatsAppSignup"
      >
        <div v-if="isFacebookLoading" class="loader mr-2 animate-spin" />
        <span>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.LOGIN_WITH_FACEBOOK.LABEL') }}
        </span>
      </button>
    </div>

    <hr class="my-6 border-t border-gray-200 dark:border-slate-700" />

    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.WHATSAPP.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.WHATSAPP.DESC')"
    />

    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
      <label>
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.LABEL') }}
        <select v-model="provider">
          <option value="whatsapp_cloud">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD') }}
          </option>
          <option value="twilio">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO') }}
          </option>
        </select>
      </label>
    </div>

    <Twilio v-if="provider === 'twilio'" type="whatsapp" />
    <ThreeSixtyDialogWhatsapp v-else-if="provider === '360dialog'" />
    <CloudWhatsapp v-else />
  </div>
</template>

<style scoped>
.facebook-login-button {
  background-color: #1877f2;
  border: 0;
  border-radius: 4px;
  color: #fff;
  cursor: pointer;
  font-family: Helvetica, Arial, sans-serif;
  font-size: 16px;
  font-weight: bold;
  height: 40px;
  padding: 0 24px;
  min-width: 200px;
}

.facebook-login-button:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.test-button {
  background-color: #4caf50;
  border: 0;
  border-radius: 4px;
  color: #fff;
  cursor: pointer;
  font-family: Helvetica, Arial, sans-serif;
  font-size: 16px;
  font-weight: bold;
  height: 40px;
  padding: 0 24px;
  min-width: 140px;
}

.test-button:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.loader {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
}

.error input {
  border-color: red;
}

.message {
  color: red;
  font-size: 0.875rem;
}
</style>
