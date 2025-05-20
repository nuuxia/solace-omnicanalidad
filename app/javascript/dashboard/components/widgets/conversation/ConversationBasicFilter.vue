<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';
import wootConstants from 'dashboard/constants/globals';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FilterItem from 'dashboard/components/widgets/conversation/FilterItem.vue';

const emit = defineEmits(['changeFilter']);
const { updateUISettings } = useUISettings();

const CHAT_STATUS_FILTER_ITEMS = Object.freeze([
  'open',
  'resolved',
  'pending',
  'snoozed',
]);

const CHAT_UNREAD_FILTER_ITEMS = Object.freeze(['read', 'unread']);

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

const [showActionsDropdown, toggleDropdown] = useToggle();

const chatStatusFilter = useMapGetter('getChatStatusFilter');
const chatSortFilter = useMapGetter('getChatSortFilter');
const chatUnreadFilter = useMapGetter('getChatUnreadFilter');

const chatStatus = computed(() =>
  chatStatusFilter.value.length
    ? chatStatusFilter.value
    : [wootConstants.STATUS_TYPE.OPEN]
);

const chatUnread = computed(
  () => chatUnreadFilter.value || wootConstants.UNREAD_TYPE.READ
);

const sortFilter = computed(
  () => chatSortFilter.value || wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC
);

const onChangeFilter = (value, type) => {
  emit('changeFilter', value, type);
  updateUISettings({
    conversations_filter_by: {
      status: type === 'status' ? value : chatStatus.value,
      order_by: type === 'sort' ? value : sortFilter.value,
      unread: type === 'unread' ? value : chatUnread.value,
    },
  });
};
</script>

<template>
  <div class="relative flex">
    <NextButton
      v-tooltip.right="$t('CHAT_LIST.SORT_TOOLTIP_LABEL')"
      icon="i-lucide-arrow-up-down"
      slate
      faded
      xs
      @click="toggleDropdown()"
    />
    <div
      v-if="showActionsDropdown"
      v-on-click-outside="() => toggleDropdown()"
      class="mt-1 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4 absolute z-40 top-full"
      :class="{
        'ltr:left-0 rtl:right-0': !isOnExpandedLayout,
        'ltr:right-0 rtl:left-0': isOnExpandedLayout,
      }"
    >
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium text-slate-800 dark:text-slate-100">
          {{ $t('CHAT_LIST.CHAT_SORT.STATUS') }}
        </span>
        <FilterItem
          type="status"
          :selected-value="chatStatus"
          :items="CHAT_STATUS_FILTER_ITEMS"
          path-prefix="CHAT_LIST.CHAT_STATUS_FILTER_ITEMS"
          @on-change-filter="onChangeFilter"
        />
      </div>

      <div class="flex items-center space-x-2 mt-4">
        <span class="text-xs font-medium text-slate-800 dark:text-slate-100">
          {{ $t('CHAT_LIST.CHAT_SORT.UNREAD') }}
        </span>
        <FilterItem
          type="unread"
          :selected-value="chatUnread"
          :items="CHAT_UNREAD_FILTER_ITEMS"
          path-prefix="CHAT_LIST.CHAT_UNREAD_FILTER_ITEMS"
          @on-change-filter="onChangeFilter"
        />
      </div>

      <div class="flex items-center justify-between last:mt-4">
        <span class="text-xs font-medium text-slate-800 dark:text-slate-100">
          {{ $t('CHAT_LIST.CHAT_SORT.ORDER_BY') }}
        </span>
        <FilterItem
          type="sort"
          :selected-value="sortFilter"
          :items="SORT_ORDER_ITEMS"
          path-prefix="CHAT_LIST.SORT_ORDER_ITEMS"
          @on-change-filter="onChangeFilter"
        />
      </div>
    </div>
  </div>
</template>
