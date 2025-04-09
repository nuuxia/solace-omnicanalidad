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
    return {
      activeValue:
        this.type === 'status'
          ? Array.isArray(this.selectedValue)
            ? [...this.selectedValue]
            : [this.selectedValue]
          : this.selectedValue, // devuelve valor único para otros filtros
    };
  },
  methods: {
    onTabChange() {
      const value = this.type === 'status' ? this.activeValue : this.activeValue;
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
  <select
    :multiple="type === 'status'"
    v-model="activeValue"
    :class="[
      'text-xs my-0 mx-1 pr-6 pl-2 border border-solid text-slate-800 dark:text-slate-100 rounded-md',
      'bg-slate-25 dark:bg-slate-700 border-slate-75 dark:border-slate-600',
      type === 'status' ? 'h-auto py-2 min-w-[10rem]' : 'h-6 py-0 w-32'
    ]"
    :size="type === 'status' ? 6 : null"
    @change="onTabChange"
  >
    <option v-for="value in items" :key="value" :value="value">
      {{ $t(`${pathPrefix}.${value}.TEXT`) }}
    </option>
  </select>
</template>

