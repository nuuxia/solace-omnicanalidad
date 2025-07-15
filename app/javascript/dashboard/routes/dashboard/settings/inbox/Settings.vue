<script>
import { mapGetters } from 'vuex';
import { shouldBeUrl } from 'shared/helpers/Validators';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import SettingIntroBanner from 'dashboard/components/widgets/SettingIntroBanner.vue';
import SettingsSection from '../../../../components/SettingsSection.vue';
import inboxMixin from 'shared/mixins/inboxMixin';
import FacebookReauthorize from './facebook/Reauthorize.vue';
import InstagramReauthorize from './channels/instagram/Reauthorize.vue';
import DuplicateInboxBanner from './channels/instagram/DuplicateInboxBanner.vue';
import MicrosoftReauthorize from './channels/microsoft/Reauthorize.vue';
import GoogleReauthorize from './channels/google/Reauthorize.vue';
import PreChatFormSettings from './PreChatForm/Settings.vue';
import WeeklyAvailability from './components/WeeklyAvailability.vue';
import GreetingsEditor from 'shared/components/GreetingsEditor.vue';
import ConfigurationPage from './settingsPage/ConfigurationPage.vue';
import CustomerSatisfactionPage from './settingsPage/CustomerSatisfactionPage.vue';
import CollaboratorsPage from './settingsPage/CollaboratorsPage.vue';
import WidgetBuilder from './WidgetBuilder.vue';
import BotConfiguration from './components/BotConfiguration.vue';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import SenderNameExamplePreview from './components/SenderNameExamplePreview.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { WIDGET_BUILDER_EDITOR_MENU_OPTIONS } from 'dashboard/constants/editor';
import Editor from 'dashboard/components-next/Editor/Editor.vue';

export default {
  components: {
    BotConfiguration,
    CollaboratorsPage,
    ConfigurationPage,
    CustomerSatisfactionPage,
    FacebookReauthorize,
    GreetingsEditor,
    PreChatFormSettings,
    SettingIntroBanner,
    SettingsSection,
    WeeklyAvailability,
    WidgetBuilder,
    SenderNameExamplePreview,
    MicrosoftReauthorize,
    GoogleReauthorize,
    NextButton,
    InstagramReauthorize,
    DuplicateInboxBanner,
    Editor,
  },
  mixins: [inboxMixin],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      avatarFile: null,
      avatarUrl: '',
      greetingEnabled: true,
      greetingMessage: '',
      emailCollectEnabled: false,
      senderNameType: 'friendly',
      userInfo: null,
      loading: false,
      error: null,
      businessName: '',
      locktoSingleConversation: false,
      allowMessagesAfterResolved: true,
      continuityViaEmail: true,
      selectedInboxName: '',
      channelWebsiteUrl: '',
      webhookUrl: '',
      channelWelcomeTitle: '',
      channelWelcomeTagline: '',
      selectedFeatureFlags: [],
      replyTime: '',
      selectedTabIndex: 0,
      selectedPortalSlug: '',
      showBusinessNameInput: false,
      welcomeTaglineEditorMenuOptions: WIDGET_BUILDER_EDITOR_MENU_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      uiFlags: 'inboxes/getUIFlags',
      portals: 'portals/allPortals',
    }),
    selectedTabKey() {
      return this.tabs[this.selectedTabIndex]?.key;
    },
    whatsAppAPIProviderName() {
      if (this.isAWhatsAppCloudChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_CLOUD');
      }
      if (this.is360DialogWhatsAppChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.360_DIALOG');
      }
      if (this.isATwilioWhatsAppChannel) {
        return this.$t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.TWILIO');
      }
      return '';
    },
    tabs() {
      let visibleToAllChannelTabs = [
        {
          key: 'inbox_settings',
          name: this.$t('INBOX_MGMT.TABS.SETTINGS'),
        },
        {
          key: 'collaborators',
          name: this.$t('INBOX_MGMT.TABS.COLLABORATORS'),
        },
        {
          key: 'businesshours',
          name: this.$t('INBOX_MGMT.TABS.BUSINESS_HOURS'),
        },
        {
          key: 'csat',
          name: this.$t('INBOX_MGMT.TABS.CSAT'),
        },
      ];

      if (this.isAWebWidgetInbox) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'preChatForm',
            name: this.$t('INBOX_MGMT.TABS.PRE_CHAT_FORM'),
          },
          {
            key: 'widgetBuilder',
            name: this.$t('INBOX_MGMT.TABS.WIDGET_BUILDER'),
          },
        ];
      }

      if (
        this.isATwilioChannel ||
        this.isALineChannel ||
        this.isAPIInbox ||
        (this.isAnEmailChannel && !this.inbox.provider) ||
        this.isAWhatsAppChannel ||
        this.isAMercadoLibreChannel ||
        this.isAWebWidgetInbox
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'configuration',
            name: this.$t('INBOX_MGMT.TABS.CONFIGURATION'),
          },
        ];
      }

      if (
        this.isFeatureEnabledonAccount(this.accountId, FEATURE_FLAGS.AGENT_BOTS)
      ) {
        visibleToAllChannelTabs = [
          ...visibleToAllChannelTabs,
          {
            key: 'botConfiguration',
            name: this.$t('INBOX_MGMT.TABS.BOT_CONFIGURATION'),
          },
        ];
      }
      return visibleToAllChannelTabs;
    },
    currentInboxId() {
      return this.$route.params.inboxId;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.currentInboxId);
    },

    inboxName() {
      if (this.isATwilioSMSChannel || this.isATwilioWhatsAppChannel) {
        return `${this.inbox.name} (${
          this.inbox.messaging_service_sid || this.inbox.phone_number
        })`;
      }
      if (this.isAWhatsAppChannel) {
        return `${this.inbox.name} (${this.inbox.phone_number})`;
      }
      if (this.isAnEmailChannel) {
        return `${this.inbox.name} (${this.inbox.email})`;
      }
      return this.inbox.name;
    },
    canLocktoSingleConversation() {
      return (
        this.isASmsInbox ||
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAPIInbox
      );
    },
    inboxNameLabel() {
      if (this.isAWebWidgetInbox) {
        return this.$t('INBOX_MGMT.ADD.WEBSITE_NAME.LABEL');
      }
      return this.$t('INBOX_MGMT.ADD.CHANNEL_NAME.LABEL');
    },
    inboxNamePlaceHolder() {
      if (this.isAWebWidgetInbox) {
        return this.$t('INBOX_MGMT.ADD.WEBSITE_NAME.PLACEHOLDER');
      }
      return this.$t('INBOX_MGMT.ADD.CHANNEL_NAME.PLACEHOLDER');
    },
    textAreaChannels() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox
      )
        return true;
      return false;
    },
    instagramUnauthorized() {
      return this.isAnInstagramChannel && this.inbox.reauthorization_required;
    },
    // Check if a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return this.inbox.channel_type === INBOX_TYPES.FB && instagramInbox;
    },
    microsoftUnauthorized() {
      return this.isAMicrosoftInbox && this.inbox.reauthorization_required;
    },
    facebookUnauthorized() {
      return this.isAFacebookInbox && this.inbox.reauthorization_required;
    },
    googleUnauthorized() {
      const isLegacyInbox = ['imap.gmail.com', 'imap.google.com'].includes(
        this.inbox.imap_address
      );

      return (
        (this.isAGoogleInbox || isLegacyInbox) &&
        this.inbox.reauthorization_required
      );
    },
  },
  watch: {
    $route(to) {
      if (to.name === 'settings_inbox_show') {
        this.fetchInboxSettings();
      }
    },
  },
  mounted() {
    this.fetchInboxSettings();
    this.fetchPortals();
  },
  methods: {
    async fetchMercadoLibreUserInfo() {
      this.loading = true;
      this.error = null;
      this.userInfo = null;
      try {
        const response = await this.$store.dispatch(
          'inboxes/getMercadoLibreUserInfo',
          {
            inbox_id: this.currentInboxId,
          }
        );
        if (response.success) {
          this.userInfo = {
            nickname: response.data.nickname,
            permalink: response.data.permalink,
          };
        } else {
          this.error = response.error;
        }
      } catch (err) {
        this.error =
          err.message || this.$t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO.ERROR');
      } finally {
        this.loading = false;
      }
    },
    fetchPortals() {
      this.$store.dispatch('portals/index');
    },
    handleFeatureFlag(e) {
      this.selectedFeatureFlags = this.toggleInput(
        this.selectedFeatureFlags,
        e.target.value
      );
    },
    toggleInput(selected, current) {
      if (selected.includes(current)) {
        const newSelectedFlags = selected.filter(flag => flag !== current);
        return newSelectedFlags;
      }
      return [...selected, current];
    },
    onTabChange(selectedTabIndex) {
      this.selectedTabIndex = selectedTabIndex;
    },
    fetchInboxSettings() {
      this.selectedTabIndex = 0;
      this.selectedAgents = [];
      this.$store.dispatch('agents/get');
      this.$store.dispatch('teams/get');
      this.$store.dispatch('labels/get');
      this.$store.dispatch('inboxes/get').then(() => {
        this.avatarUrl = this.inbox.avatar_url;
        this.selectedInboxName = this.inbox.name;
        this.webhookUrl = this.inbox.webhook_url;
        this.greetingEnabled = this.inbox.greeting_enabled || false;
        this.greetingMessage = this.inbox.greeting_message || '';
        this.emailCollectEnabled = this.inbox.enable_email_collect;
        this.senderNameType = this.inbox.sender_name_type;
        this.businessName = this.inbox.business_name;
        this.allowMessagesAfterResolved =
          this.inbox.allow_messages_after_resolved;
        this.continuityViaEmail = this.inbox.continuity_via_email;
        this.channelWebsiteUrl = this.inbox.website_url;
        this.channelWelcomeTitle = this.inbox.welcome_title;
        this.channelWelcomeTagline = this.inbox.welcome_tagline;
        this.selectedFeatureFlags = this.inbox.selected_feature_flags || [];
        this.replyTime = this.inbox.reply_time;
        this.locktoSingleConversation = this.inbox.lock_to_single_conversation;
        this.selectedPortalSlug = this.inbox.help_center
          ? this.inbox.help_center.slug
          : '';
      });
    },
    async updateInbox() {
      try {
        const payload = {
          id: this.currentInboxId,
          name: this.selectedInboxName,
          enable_email_collect: this.emailCollectEnabled,
          allow_messages_after_resolved: this.allowMessagesAfterResolved,
          greeting_enabled: this.greetingEnabled,
          offline_response: this.inbox.offline_response,
          mercado_libre_pre_sale_questions:
            this.inbox.mercado_libre_pre_sale_questions,
          mercado_libre_post_sale_messages:
            this.inbox.mercado_libre_post_sale_messages,
          greeting_message: this.greetingMessage || '',
          portal_id: this.selectedPortalSlug
            ? this.portals.find(
                portal => portal.slug === this.selectedPortalSlug
              ).id
            : null,
          lock_to_single_conversation: this.locktoSingleConversation,
          sender_name_type: this.senderNameType,
          business_name: this.businessName || null,
          channel: {
            widget_color: this.inbox.widget_color,
            website_url: this.channelWebsiteUrl,
            webhook_url: this.webhookUrl,
            welcome_title: this.channelWelcomeTitle || '',
            welcome_tagline: this.channelWelcomeTagline || '',
            selectedFeatureFlags: this.selectedFeatureFlags,
            reply_time: this.replyTime || 'in_a_few_minutes',
            continuity_via_email: this.continuityViaEmail,
          },
        };
        if (this.avatarFile) {
          payload.avatar = this.avatarFile;
        }
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(error.message || this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },
    async handleAvatarDelete() {
      try {
        await this.$store.dispatch(
          'inboxes/deleteInboxAvatar',
          this.currentInboxId
        );
        this.avatarFile = null;
        this.avatarUrl = '';
        useAlert(this.$t('INBOX_MGMT.DELETE.API.AVATAR_SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('INBOX_MGMT.DELETE.API.AVATAR_ERROR_MESSAGE')
        );
      }
    },
    toggleSenderNameType(key) {
      this.senderNameType = key;
    },
    onClickShowBusinessNameInput() {
      this.showBusinessNameInput = !this.showBusinessNameInput;
      if (this.showBusinessNameInput) {
        this.$nextTick(() => {
          this.$refs.businessNameInput.focus();
        });
      }
    },
  },
  validations: {
    webhookUrl: {
      shouldBeUrl,
    },
    selectedInboxName: {},
  },
};
</script>

<template>
  <div
    class="flex-grow flex-shrink w-full min-w-0 pl-0 pr-0 overflow-auto settings"
  >
    <SettingIntroBanner
      :header-image="inbox.avatarUrl"
      :header-title="inboxName"
    >
      <woot-tabs
        class="[&_ul]:p-0"
        :index="selectedTabIndex"
        :border="false"
        @change="onTabChange"
      >
        <woot-tabs-item
          v-for="(tab, index) in tabs"
          :key="tab.key"
          :index="index"
          :name="tab.name"
          :show-badge="false"
          is-compact
        />
      </woot-tabs>
    </SettingIntroBanner>
    <section class="w-full max-w-6xl mx-auto">
      <MicrosoftReauthorize v-if="microsoftUnauthorized" :inbox="inbox" />
      <FacebookReauthorize v-if="facebookUnauthorized" :inbox="inbox" />
      <GoogleReauthorize v-if="googleUnauthorized" :inbox="inbox" />
      <InstagramReauthorize v-if="instagramUnauthorized" :inbox="inbox" />
      <DuplicateInboxBanner
        v-if="hasDuplicateInstagramInbox"
        :content="$t('INBOX_MGMT.ADD.INSTAGRAM.DUPLICATE_INBOX_BANNER')"
        class="mx-8 mt-5"
      />
      <div v-if="selectedTabKey === 'inbox_settings'" class="mx-8">
        <SettingsSection
          :title="$t('INBOX_MGMT.SETTINGS_POPUP.INBOX_UPDATE_TITLE')"
          :sub-title="$t('INBOX_MGMT.SETTINGS_POPUP.INBOX_UPDATE_SUB_TEXT')"
          :show-border="false"
        >
          <woot-avatar-uploader
            :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_AVATAR.LABEL')"
            :src="avatarUrl"
            class="pb-4"
            delete-avatar
            @on-avatar-select="handleImageUpload"
            @on-avatar-delete="handleAvatarDelete"
          />
          <woot-input
            v-model="selectedInboxName"
            class="pb-4"
            :class="{ error: v$.selectedInboxName.$error }"
            :label="inboxNameLabel"
            :placeholder="inboxNamePlaceHolder"
            :error="
              v$.selectedInboxName.$error
                ? $t('INBOX_MGMT.ADD.CHANNEL_NAME.ERROR')
                : ''
            "
            @blur="v$.selectedInboxName.$touch"
          />
          <woot-input
            v-if="isAPIInbox"
            v-model="webhookUrl"
            class="pb-4"
            :class="{ error: v$.webhookUrl.$error }"
            :label="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.LABEL')
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.PLACEHOLDER'
              )
            "
            :error="
              v$.webhookUrl.$error
                ? $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WEBHOOK_URL.ERROR')
                : ''
            "
            @blur="v$.webhookUrl.$touch"
          />
          <woot-input
            v-if="isAWebWidgetInbox"
            v-model="channelWebsiteUrl"
            class="pb-4"
            :label="$t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.LABEL')"
            :placeholder="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_DOMAIN.PLACEHOLDER')
            "
          />
          <woot-input
            v-if="isAWebWidgetInbox"
            v-model="channelWelcomeTitle"
            class="pb-4"
            :label="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.LABEL')
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TITLE.PLACEHOLDER'
              )
            "
          />
          <Editor
            v-if="isAWebWidgetInbox"
            v-model="channelWelcomeTagline"
            class="mb-4"
            :label="
              $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.LABEL')
            "
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WEBSITE_CHANNEL.CHANNEL_WELCOME_TAGLINE.PLACEHOLDER'
              )
            "
            :max-length="255"
            :enabled-menu-options="welcomeTaglineEditorMenuOptions"
          />
          <label v-if="isAWebWidgetInbox" class="pb-4">
            {{ $t('INBOX_MGMT.ADD.WEBSITE_CHANNEL.WIDGET_COLOR.LABEL') }}
            <woot-color-picker v-model="inbox.widget_color" />
          </label>
          <label v-if="isAWhatsAppChannel" class="pb-4">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.LABEL') }}
            <input v-model="whatsAppAPIProviderName" type="text" disabled />
          </label>
          <div class="w-3/4 pb-4">
            <label>
              {{ $t('INBOX_MGMT.HELP_CENTER.LABEL') }}
            </label>
            <select v-model="selectedPortalSlug" class="filter__question">
              <option value="">
                {{ $t('INBOX_MGMT.HELP_CENTER.PLACEHOLDER') }}
              </option>
              <option v-for="p in portals" :key="p.slug" :value="p.slug">
                {{ p.name }}
              </option>
            </select>
            <p
              class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400"
            >
              {{ $t('INBOX_MGMT.HELP_CENTER.SUB_TEXT') }}
            </p>
          </div>
          <div v-if="isAMercadoLibreChannel" class="w-3/4 pb-4">
            <label class="font-bold text-lg">
              {{ $t('INBOX_MGMT.MERCADO_LIBRE_OPTIONS_HEADER') }}
            </label>
            <div class="mt-2 space-y-2">
              <label class="flex items-center space-x-2">
                <input
                  v-model="inbox.mercado_libre_pre_sale_questions"
                  type="checkbox"
                />
                <span>{{ $t('INBOX_MGMT.ENABLE_PRE_SALE_MESSAGES') }}</span>
              </label>
              <label class="flex items-center space-x-2">
                <input
                  v-model="inbox.mercado_libre_post_sale_messages"
                  type="checkbox"
                />
                <span>{{ $t('INBOX_MGMT.ENABLE_POST_SALE_MESSAGES') }}</span>
              </label>
            </div>
          </div>
          <label class="flex items-center space-x-2 mb-4 mt-4">
            <input v-model="inbox.offline_response" type="checkbox" />
            <span>{{ $t('INBOX_MGMT.OFFLINE_RESPONSE_LABEL') }}</span>
          </label>
          <label v-if="canLocktoSingleConversation" class="w-3/4 pb-4">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.LOCK_TO_SINGLE_CONVERSATION') }}
            <select v-model="locktoSingleConversation">
              <option :value="true">
                {{ $t('INBOX_MGMT.EDIT.LOCK_TO_SINGLE_CONVERSATION.ENABLED') }}
              </option>
              <option :value="false">
                {{ $t('INBOX_MGMT.EDIT.LOCK_TO_SINGLE_CONVERSATION.DISABLED') }}
              </option>
            </select>
            <p
              class="pb-1 text-sm not-italic text-slate-600 dark:text-slate-400"
            >
              {{
                $t(
                  'INBOX_MGMT.SETTINGS_POPUP.LOCK_TO_SINGLE_CONVERSATION_SUB_TEXT'
                )
              }}
            </p>
          </label>
          <div v-if="isAWebWidgetInbox" class="flex gap-2 pb-4">
            <input
              v-model="selectedFeatureFlags"
              type="checkbox"
              value="end_conversation"
              @input="handleFeatureFlag"
            />
            <label for="end_conversation">
              {{ $t('INBOX_MGMT.FEATURES.ALLOW_END_CONVERSATION') }}
            </label>
          </div>
          <div v-if="isAWebWidgetInbox" class="flex gap-2 pb-4">
            <input
              v-model="selectedFeatureFlags"
              type="checkbox"
              value="use_inbox_avatar_for_bot"
              @input="handleFeatureFlag"
            />
            <label for="use_inbox_avatar_for_bot">
              {{ $t('INBOX_MGMT.FEATURES.USE_INBOX_AVATAR_FOR_BOT') }}
            </label>
          </div>
        </SettingsSection>
        <SettingsSection
          v-if="isAMercadoLibreChannel"
          :title="$t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO.TITLE')"
          :sub-title="$t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO.SUB_TEXT')"
          :show-border="false"
        >
          <div class="bg-gray-100 dark:bg-slate-900 p-4 rounded-2xl shadow-md">
            <woot-button
              variant="primary"
              class="mb-4"
              :loading="loading"
              @click="fetchMercadoLibreUserInfo"
            >
              {{ $t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO_BUTTON') }}
            </woot-button>
            <div v-if="loading" class="text-gray-600 dark:text-gray-300">
              {{ $t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO.LOADING') }}
            </div>
            <div v-if="userInfo" class="flex flex-col space-y-2">
              <div class="flex items-center space-x-2">
                <span class="font-semibold">{{
                    $t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO.NICKNAME')
                  }}:</span>
                <span class="text-primary-600 dark:text-primary-400">{{
                  userInfo.nickname
                }}</span>
              </div>
              <div class="flex items-center space-x-2">
                <span class="font-semibold">{{
                    $t('INBOX_MGMT.MERCADO_LIBRE_USER_INFO.PERMALINK')
                  }}:</span>
                <a
                  :href="userInfo.permalink"
                  target="_blank"
                  class="text-blue-600 dark:text-blue-400 underline"
                >
                  {{ userInfo.permalink }}
                </a>
              </div>
            </div>
            <div v-if="error" class="text-red-500">
              {{ error }}
            </div>
          </div>
        </SettingsSection>
        <SettingsSection
          v-if="isAWebWidgetInbox || isAnEmailChannel"
          :title="$t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.TITLE')"
          :sub-title="$t('INBOX_MGMT.EDIT.SENDER_NAME_SECTION.SUB_TEXT')"
          :show-border="false"
        >
          <div class="w-3/4 pb-4">
            <SenderNameExamplePreview
              :sender-name-type="senderNameType"
              :business-name="businessName"
              @update="toggleSenderNameType"
            />
            <div class="flex flex-col items-start gap-2 mt-2">
              <woot-button
                variant="clear"
                color-scheme="primary"
                @click="onClickShowBusinessNameInput"
              >
                {{
                  $t(
                    'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.BUTTON_TEXT'
                  )
                }}
              </woot-button>
              <div v-if="showBusinessNameInput" class="flex gap-2 w-[80%]">
                <input
                  ref="businessNameInput"
                  v-model="businessName"
                  :placeholder="
                    $t(
                      'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.PLACEHOLDER'
                    )
                  "
                  class="mb-0"
                  type="text"
                />
                <woot-button color-scheme="primary" @click="updateInbox">
                  {{
                    $t(
                      'INBOX_MGMT.EDIT.SENDER_NAME_SECTION.BUSINESS_NAME.SAVE_BUTTON_TEXT'
                    )
                  }}
                </woot-button>
              </div>
            </div>
          </div>
        </SettingsSection>
        <SettingsSection :show-border="false">
          <NextButton
            v-if="isAPIInbox"
            type="submit"
            :disabled="v$.webhookUrl.$invalid"
            :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
            :is-loading="uiFlags.isUpdating"
            @click="updateInbox"
          />
          <NextButton
            v-else
            type="submit"
            :disabled="v$.$invalid"
            :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
            :is-loading="uiFlags.isUpdating"
            @click="updateInbox"
          />
        </SettingsSection>
      </div>
      <div v-if="selectedTabKey === 'collaborators'" class="mx-8">
        <CollaboratorsPage :inbox="inbox" />
      </div>
      <div v-if="selectedTabKey === 'configuration'">
        <ConfigurationPage :inbox="inbox" />
      </div>
      <div v-if="selectedTabKey === 'csat'">
        <CustomerSatisfactionPage :inbox="inbox" />
      </div>
      <div v-if="selectedTabKey === 'preChatForm'">
        <PreChatFormSettings :inbox="inbox" />
      </div>
      <div v-if="selectedTabKey === 'businesshours'">
        <WeeklyAvailability :inbox="inbox" />
      </div>
      <div v-if="selectedTabKey === 'widgetBuilder'">
        <WidgetBuilder :inbox="inbox" />
      </div>
      <div v-if="selectedTabKey === 'botConfiguration'">
        <BotConfiguration :inbox="inbox" />
      </div>
    </section>
  </div>
</template>
