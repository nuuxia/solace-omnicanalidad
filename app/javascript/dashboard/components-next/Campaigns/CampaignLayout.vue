<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  headerTitle: {
    type: String,
    default: '',
  },
  /* ───────── primer botón (ya existía) ───────── */
  buttonLabel: {
    type: String,
    default: '',
  },
  /* ───────── segundo botón (¡nuevo!) ───────── */
  secondButtonLabel: {
    type: String,
    default: '', // si viene vacío, no se dibuja
  },
});

const emit = defineEmits(['click', 'secondClick', 'close']);

const handleButtonClick = () => emit('click');
const handleSecondButtonClick = () => emit('secondClick');
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <header class="sticky top-0 z-10 px-6 lg:px-0">
      <div class="w-full max-w-[960px] mx-auto">
        <div class="flex items-center justify-between w-full h-20 gap-2">
          <span class="text-xl font-medium text-n-slate-12">
            {{ headerTitle }}
          </span>

          <!-- CONTENEDOR: botón(es) + slot -->
          <div
            v-on-clickaway="() => emit('close')"
            class="relative flex items-center gap-2 group/campaign-button"
          >
            <Button
              :label="buttonLabel"
              icon="plus"
              size="sm"
              class="group-hover/campaign-button:brightness-110"
              @click="handleButtonClick"
            />

            <!-- botón secundario (solo si trae label) -->
            <Button
              v-if="secondButtonLabel"
              :label="secondButtonLabel"
              icon="plus"
              size="sm"
              class="group-hover/campaign-button:brightness-110"
              @click="handleSecondButtonClick"
            />

            <!-- slot por si alguien quiere inyectar algo más -->
            <slot name="action" />
          </div>
        </div>
      </div>
    </header>

    <main class="flex-1 px-6 overflow-y-auto lg:px-0">
      <div class="w-full max-w-[960px] mx-auto py-4">
        <slot />
      </div>
    </main>
  </section>
</template>
