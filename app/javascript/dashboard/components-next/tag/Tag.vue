<script setup>
/**
 * Pequeño badge/redondeado para estados.
 * variant:  info | primary | success | danger
 * size:     sm    | md
 */
const props = defineProps({
  variant: { type: String, default: 'info' }, // color
  size: { type: String, default: 'sm' }, // alto / padding
});

/* clases base */
const base =
  'inline-flex items-center rounded-md font-medium whitespace-nowrap';
const sizeClasses = {
  sm: 'text-xs h-6 px-2 py-0.5',
  md: 'text-sm h-7 px-3 py-0.5',
};
const colorClasses = {
  info: 'bg-n-alpha-2  text-n-slate-11',
  primary: 'bg-n-teal-3   text-n-teal-11',
  success: 'bg-n-green-3  text-n-green-11',
  danger: 'bg-n-ruby-3   text-n-ruby-11',
};
</script>

<template>
  <span :class="[base, sizeClasses[size], colorClasses[variant]]">
    <slot />
  </span>
</template>
