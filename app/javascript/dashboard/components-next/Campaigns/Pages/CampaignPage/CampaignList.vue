<script setup>
/**
 * Lista de campañas (Live-chat, SMS, WhatsApp-CSV…).
 * Propaga los eventos:
 *   • edit(campaign)
 *   • delete(campaign)
 *   • stats(campaign)   ← NUEVO
 */

import CampaignCard from 'dashboard/components-next/Campaigns/CampaignCard/CampaignCard.vue';

const props = defineProps({
  campaigns:      { type: Array,  required: true },
  isLiveChatType: { type: Boolean, default: false },
  enableStats:    { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'delete', 'stats'])

/* helpers ------------------------------------------------------- */
const handleEdit   = c => emit('edit',   c);
const handleDelete = c => emit('delete', c);
const handleStats  = c => emit('stats',  c);   // ← NUEVO
</script>

<template>
  <div class="flex flex-col gap-4">
    <CampaignCard
      v-for="campaign in campaigns"
      :key="campaign.id"
      :title="campaign.title"
      :message="campaign.message"
      :template="campaign.template"
      :is-enabled="campaign.enabled"
      :status="campaign.campaign_status"
      :sender="campaign.sender"
      :inbox="campaign.inbox"
      :scheduled-at="campaign.scheduled_at"
      :is-live-chat-type="isLiveChatType"
      :show-stats="enableStats"
      @edit="() => handleEdit(campaign)"
      @delete="() => handleDelete(campaign)"
      @stats="() => handleStats(campaign)"
    />
  </div>
</template>
