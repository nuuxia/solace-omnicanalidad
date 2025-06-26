<script setup>
import { computed } from 'vue';
const props = defineProps({
  value: { type: Number, default: 0 },
  color: { type: String, default: 'bg-green-500' },
});
const pct = computed(() => Math.min(100, Math.max(0, props.value)));
</script>

<template>
  <div class="w-full h-2 rounded bg-slate-200 overflow-hidden">
    <div :class="['h-full transition-all duration-300', color]"
         :style="{ width: pct + '%' }"/>
  </div>
</template>
