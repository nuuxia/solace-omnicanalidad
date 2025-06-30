// utils/campaignStatus.js (o donde prefieras)
export function getCampaignStatusLabel(
  { messages_total, messages_sent, messages_failed },
  t
) {
  const total = +messages_total || 0;
  const sent = +messages_sent || 0;
  const failed = +messages_failed || 0;
  const pending = Math.max(total - sent - failed, 0);

  return pending
    ? t('CAMPAIGN.CSV.WHATSAPP.CARD.STATUS.ENABLED')
    : t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED');
}
