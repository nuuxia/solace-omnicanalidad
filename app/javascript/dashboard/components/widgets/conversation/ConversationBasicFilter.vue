<script>
import wootConstants from 'dashboard/constants/globals';
import { mapGetters } from 'vuex';
import FilterItem from './FilterItem.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

const CHAT_STATUS_FILTER_ITEMS = Object.freeze([
  'open',
  'resolved',
  'pending',
  'snoozed',
  'all',
]);

const SORT_ORDER_ITEMS = Object.freeze([
  'last_activity_at_asc',
  'last_activity_at_desc',
  'created_at_desc',
  'created_at_asc',
  'priority_desc',
  'priority_asc',
  'waiting_since_asc',
  'waiting_since_desc',
]);

export default {
  components: {
    FilterItem,
  },
  emits: ['changeFilter'],
  setup() {
    const { updateUISettings } = useUISettings();

    return {
      updateUISettings,
    };
  },
  data() {
    return {
      showActionsDropdown: false,
      chatStatusItems: CHAT_STATUS_FILTER_ITEMS,
      chatSortItems: SORT_ORDER_ITEMS,
      unreadFilter: false,
    };
  },
  computed: {
    ...mapGetters({
      chatStatusFilter: 'getChatStatusFilter',
      chatSortFilter: 'getChatSortFilter',
    }),
    chatStatus() {
      return this.chatStatusFilter || wootConstants.STATUS_TYPE.OPEN;
    },
    sortFilter() {
      return (
        this.chatSortFilter || wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC
      );
    },
  },
  methods: {
    onTabChange(value) {
      this.$emit('changeFilter', value);
      this.closeDropdown();
    },
    toggleDropdown() {
      this.showActionsDropdown = !this.showActionsDropdown;
    },
    closeDropdown() {
      this.showActionsDropdown = false;
    },
    // onChangeFilter(value, type) {
    //   this.$emit('changeFilter', value, type);
    //   this.saveSelectedFilter(type, value);
    // },
    onChangeFilter(value, type) {
      if (type === 'status') {
        this.$store.dispatch('setChatStatusFilter', value);
      } else if (type === 'sort') {
        this.$store.dispatch('setChatSortFilter', value);
      } else {
        // Caso del checkbox unread, no persistimos en el store
        this.$store.dispatch('fetchAllConversations', { unread: value });
      }
      this.$emit('changeFilter', value, type || 'unread');
      this.saveSelectedFilter(type || 'unread', value);
    },
    saveSelectedFilter(type, value) {
      this.updateUISettings({
        conversations_filter_by: {
          status: type === 'status' ? value : this.chatStatus,
          order_by: type === 'sort' ? value : this.sortFilter,
          // No persistimos unread en el store, pero lo guardamos en UI settings si es necesario
          unread: type === 'unread' ? value : undefined,
        },
      });
    },
  },
};
</script>

<template>
  <div class="relative flex">
    <woot-button
      v-tooltip.right="$t('CHAT_LIST.SORT_TOOLTIP_LABEL')"
      variant="smooth"
      size="tiny"
      color-scheme="secondary"
      class="selector-button"
      icon="sort-icon"
      @click="toggleDropdown"
    />
    <div
      v-if="showActionsDropdown"
      v-on-clickaway="closeDropdown"
      class="right-0 mt-1 dropdown-pane dropdown-pane--open basic-filter"
    >
    <div class="flex items-center justify-between last:mt-4">
      <span class="text-xs font-medium text-slate-800 dark:text-slate-100">{{
        $t('CHAT_LIST.CHAT_SORT.STATUS')
      }}</span>
      <FilterItem
        type="status"
        :selected-value="chatStatus"
        :items="chatStatusItems"
        path-prefix="CHAT_LIST.CHAT_STATUS_FILTER_ITEMS"
        @on-change-filter="onChangeFilter"
      />
    </div>
    <div class="flex items-center space-x-2 mt-4">
      <input
        id="unreadCheckbox"
        type="checkbox"
        v-model="unreadFilter"
        class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
        @change="onChangeFilter"
      />
      <label for="unreadCheckbox" class="text-xs font-medium text-slate-800 dark:text-slate-100">
        {{ $t('CHAT_LIST.CHAT_SORT.UNREAD') }}
      </label>
    </div>
    <div class="flex items-center justify-between last:mt-4">
      <span class="text-xs font-medium text-slate-800 dark:text-slate-100">{{
        $t('CHAT_LIST.CHAT_SORT.ORDER_BY')
      }}</span>
      <FilterItem
        type="sort"
        :selected-value="sortFilter"
        :items="chatSortItems"
        path-prefix="CHAT_LIST.SORT_ORDER_ITEMS"
        @on-change-filter="onChangeFilter"
      />
    </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.basic-filter {
  @apply w-52 p-4 top-6;
}
</style>
