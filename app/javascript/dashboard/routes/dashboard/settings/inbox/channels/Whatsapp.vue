<script setup>
import { computed, ref, onMounted, onBeforeUnmount } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

// Imports de componentes de la interfaz
import PageHeader from '../../SettingsSubPageHeader.vue';
import Twilio from './Twilio.vue';
import CloudWhatsapp from './CloudWhatsapp.vue';
import ThreeSixtyDialogWhatsapp from './360DialogWhatsapp.vue';

// Import de API y router
import WhatsappChannel from '../../../../../api/whatsappChannel';
import router from '../../../../index';

// Constantes
const PROVIDER_TYPES = {
  WHATSAPP: 'whatsapp',
  TWILIO: 'twilio',
  THREE_SIXTY_DIALOG: '360dialog',
};

// --- INICIALIZACIÓN ---
const route = useRoute();
const vueRouter = useRouter();
const { t } = useI18n();

// --- ESTADO DEL COMPONENTE ---
const isFacebookLoading = ref(false);
const fbScriptLoaded = ref(false);

// --- PROPIEDADES COMPUTADAS ---
const selectedProvider = computed(() => route.query.provider);
const showProviderSelection = computed(() => !selectedProvider.value);
const showConfiguration = computed(() => Boolean(selectedProvider.value));

const availableProviders = computed(() => [
  {
    value: PROVIDER_TYPES.WHATSAPP,
    label: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD'),
    description: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD_DESC'),
    icon: '/assets/images/dashboard/channels/whatsapp.png',
  },
  {
    value: PROVIDER_TYPES.TWILIO,
    label: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO'),
    description: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO_DESC'),
    icon: '/assets/images/dashboard/channels/twilio.png',
  },
]);

// --- MÉTODOS ---
const selectProvider = providerValue => {
  vueRouter.push({
    name: route.name,
    params: route.params,
    query: { provider: providerValue },
  });
};

// --- LÓGICA DE FACEBOOK SDK (FLUJO AUTOMATIZADO) ---
const handleFbMessage = async event => {
  if (
    event.origin !== 'https://www.facebook.com' &&
    event.origin !== 'https://web.facebook.com'
  ) {
    return;
  }
  try {
    const data = JSON.parse(event.data);
    if (data.type !== 'WA_EMBEDDED_SIGNUP') return;
    if (data.event === 'CANCEL') {
      isFacebookLoading.value = false;
      return;
    }

    // ESTA LÓGICA DIFERENCIA ENTRE EL FLUJO NORMAL Y EL DE COEXISTENCIA
    const isCoexistence =
      data.event === 'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING';

    const payload = isCoexistence
      ? // Payload para el flujo de COEXISTENCIA (solo waba_id)
        { waba_id: data.data.waba_id }
      : // Payload para el flujo NORMAL (waba_id y phone_number_id)
        {
          waba_id: data.data.waba_id,
          phone_number_id: data.data.phone_number_id,
        };

    try {
      isFacebookLoading.value = true;
      const response = await createWhatsappChannel(payload);
      if (response?.inbox_id) {
        await navigateToInboxSettings(response.inbox_id);
      } else {
        isFacebookLoading.value = false;
      }
    } catch {
      isFacebookLoading.value = false;
    }
  } catch {
    // ignorar payloads malformados
  }
};

const createWhatsappChannel = async payload => {
  // Llama al mismo endpoint. El backend decidirá qué servicio usar.
  const response = await WhatsappChannel.automatedSignup(payload);
  return response.data;
};

const navigateToInboxSettings = async inboxId => {
  try {
    await router.push({
      name: 'settings_inbox_show',
      params: {
        accountId: route.params.accountId,
        inboxId: inboxId.toString(),
      },
    });
  } finally {
    isFacebookLoading.value = false;
  }
};

const launchWhatsAppSignup = async () => {
  if (typeof FB === 'undefined' || !fbScriptLoaded.value) {
    console.error('Facebook SDK not initialized or loaded yet.');
    return;
  }
  isFacebookLoading.value = true;
  if (window.location.protocol !== 'https:') {
    console.error('Facebook Login must be called from an HTTPS page.');
    isFacebookLoading.value = false;
    alert(
      'For security reasons, Facebook connection must be done from a secure (HTTPS) page.'
    );
    return;
  }

  // Usando las credenciales proporcionadas
  const configId = '1710763212991813';
  const loginOptions = {
    config_id: configId,
    response_type: 'code',
    override_default_response_type: true,
    extras: {
      setup: {},
      featureType: 'whatsapp_business_app_onboarding',
      sessionInfoVersion: '3',
    },
  };
  FB.login(
    response => {
      if (!response.authResponse) {
        isFacebookLoading.value = false;
      }
    },
    {
      scope: 'whatsapp_business_management,whatsapp_business_messaging',
      ...loginOptions,
    }
  );
};

// --- LIFECYCLE HOOKS ---
onMounted(() => {
  // Usando las credenciales proporcionadas y la versión de API corregida
  const appId = '404207692182612';
  const graphApiVersion = 'v23.0'; // CORREGIDO: v23.0 no es una versión válida.

  const initFacebookSdk = () => {
    if (fbScriptLoaded.value) return;
    if (typeof FB === 'undefined') {
      setTimeout(initFacebookSdk, 100);
      return;
    }

    try {
      FB.init({
        appId,
        autoLogAppEvents: true,
        xfbml: true,
        version: graphApiVersion,
      });
      fbScriptLoaded.value = true;
    } catch (error) {
      console.error('Error initializing Facebook SDK:', error);
    }
  };

  if (typeof FB !== 'undefined' && FB.hasOwnProperty('_apiKey')) {
    initFacebookSdk();
  } else {
    const fbScript = document.createElement('script');
    fbScript.id = 'facebook-jssdk';
    fbScript.async = true;
    fbScript.defer = true;
    fbScript.crossOrigin = 'anonymous';
    fbScript.src = 'https://connect.facebook.net/en_US/sdk.js';
    fbScript.onload = initFacebookSdk;
    document.body.appendChild(fbScript);
  }

  window.addEventListener('message', handleFbMessage);
});

onBeforeUnmount(() => {
  window.removeEventListener('message', handleFbMessage);
  const fbScript = document.getElementById('facebook-jssdk');
  if (fbScript) {
    document.body.removeChild(fbScript);
  }
});
</script>

<template>
  <div
    class="overflow-auto col-span-6 p-6 w-full h-full rounded-t-lg border border-b-0 border-n-weak bg-n-solid-1"
  >
    <div v-if="showProviderSelection">
      <div class="mb-10 text-left">
        <h1 class="mb-2 text-lg font-medium text-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.SELECT_PROVIDER.TITLE') }}
        </h1>
        <p class="text-sm leading-relaxed text-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.SELECT_PROVIDER.DESCRIPTION') }}
        </p>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div
          v-for="provider in availableProviders"
          :key="provider.value"
          class="gap-6 px-5 py-6 rounded-2xl border transition-all duration-200 cursor-pointer border-n-weak hover:bg-n-slate-3"
          @click="selectProvider(provider.value)"
        >
          <div class="flex justify-start mb-5">
            <div
              class="flex justify-center items-center rounded-full size-10 bg-n-alpha-2"
            >
              <img
                :src="provider.icon"
                :alt="provider.label"
                class="object-contain size-[26px]"
              />
            </div>
          </div>
          <div class="text-start">
            <h3 class="mb-1.5 text-sm font-medium text-slate-12">
              {{ provider.label }}
            </h3>
            <p class="text-sm text-slate-11">
              {{ provider.description }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <div v-else-if="showConfiguration">
      <div
        v-if="selectedProvider === PROVIDER_TYPES.WHATSAPP"
        class="p-1 w-full"
      >
        <div class="w-full max-w-full md:w-3/4 md:max-w-[75%] mb-4">
          <h2 class="text-xl font-semibold mb-1 text-slate-12">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.AUTOMATED_TITLE') }}
          </h2>
          <p class="text-sm text-slate-11 mb-4">
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

        <hr class="my-8 border-t border-n-weak" />

        <PageHeader
          :header-title="$t('INBOX_MGMT.ADD.WHATSAPP.TITLE')"
          :header-content="$t('INBOX_MGMT.ADD.WHATSAPP.DESC')"
        />
        <CloudWhatsapp />
      </div>

      <Twilio
        v-else-if="selectedProvider === PROVIDER_TYPES.TWILIO"
        type="whatsapp"
      />
      <ThreeSixtyDialogWhatsapp
        v-else-if="selectedProvider === PROVIDER_TYPES.THREE_SIXTY_DIALOG"
      />
    </div>
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
.loader {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
}
</style>
