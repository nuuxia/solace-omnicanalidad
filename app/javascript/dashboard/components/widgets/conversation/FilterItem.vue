<script>
export default {
  props: {
    items: {
      type: Array,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
    pathPrefix: {
      type: String,
      required: true,
    },
    selectedValue: {
      type: [Array, String],
      default: () => [],
    },
  },
  emits: ['onChangeFilter'],
  data() {
    let activeValue;

    if (this.type === 'status') {
      activeValue = Array.isArray(this.selectedValue)
        ? [...this.selectedValue]
        : [this.selectedValue];
    } else {
      activeValue = this.selectedValue;
    }

    return { activeValue };
  },
  methods: {
    onTabChange() {
      const value =
        this.type === 'status' ? this.activeValue : this.activeValue;
      this.updateStore(value);
      this.$emit('onChangeFilter', value, this.type);
    },
    updateStore(value) {
      if (this.type === 'status') {
        this.$store.dispatch('setChatStatusFilter', value);
      } else if (this.type === 'unread') {
        this.$store.dispatch('setChatUnreadFilter', value);
      } else {
        this.$store.dispatch('setChatSortFilter', value);
      }
    },
  },
};
</script>

<template>
  <div class="flex items-center space-x-2 w-full">
    <!-- Multiselect for type === 'status' -->
    <div v-if="type === 'status'" class="relative w-full">
      <div
        class="w-full max-w-56 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-md shadow-sm"
      >
        <div class="max-h-48 overflow-y-auto">
          <label
            v-for="value in items"
            :key="value"
            class="flex items-center px-3 py-2 hover:bg-slate-100 dark:hover:bg-slate-700 cursor-pointer"
          >
            <input
              v-model="activeValue"
              type="checkbox"
              :value="value"
              class="w-4 h-4 text-blue-600 border-slate-300 rounded focus:ring-blue-500"
              @change="onTabChange"
            />
            <span class="ml-2 text-sm text-slate-800 dark:text-slate-100">
              {{ $t(`${pathPrefix}.${value}.TEXT`) }}
            </span>
          </label>
        </div>
      </div>
    </div>

    <!-- Simple select for other types -->
    <div v-else class="relative w-full">
      <select
        v-model="activeValue"
        class="w-full max-w-56 h-10 px-3 py-2 text-sm text-slate-800 dark:text-slate-100 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none"
        @change="onTabChange"
      >
        <option v-for="value in items" :key="value" :value="value">
          {{ $t(`${pathPrefix}.${value}.TEXT`) }}
        </option>
      </select>
    </div>
  </div>
</template>

<style scoped>
/* Scrollbar styles for multiselect */
.max-h-48::-webkit-scrollbar {
  width: 6px;
}
.max-h-48::-webkit-scrollbar-thumb {
  background-color: #94a3b8;
  border-radius: 3px;
}
.max-h-48::-webkit-scrollbar-track {
  background: #f1f5f9;
}
.dark .max-h-48::-webkit-scrollbar-thumb {
  background-color: #64748b;
}
.dark .max-h-48::-webkit-scrollbar-track {
  background: #1e293b;
}

/* Hide native select arrow */
select {
  -webkit-appearance: none;
  -moz-appearance: none;
  appearance: none;
}

/* Responsive adjustments */
@media (max-width: 640px) {
  .max-w-56 {
    max-width: 100%; /* Full width on small screens */
  }
  .text-sm {
    font-size: 0.75rem; /* Smaller text on small screens */
  }
  .h-10 {
    height: 2rem; /* Smaller height for select on small screens */
  }
}
</style>
