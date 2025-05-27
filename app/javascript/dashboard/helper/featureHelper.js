const FEATURE_HELP_URLS = {
  agent_bots: 'https://softwarearrows.com/hc/agent-bots',
  agents: 'https://softwarearrows.com/hc/agents',
  audit_logs: 'https://softwarearrows.com/hc/audit-logs',
  campaigns: 'https://softwarearrows.com/hc/campaigns',
  canned_responses: 'https://softwarearrows.com/hc/canned',
  channel_email: 'https://softwarearrows.com/hc/email',
  channel_facebook: 'https://softwarearrows.com/hc/fb',
  custom_attributes: 'https://softwarearrows.com/hc/custom-attributes',
  dashboard_apps: 'https://softwarearrows.com/hc/dashboard-apps',
  help_center: 'https://softwarearrows.com/hc/help-center',
  inboxes: 'https://softwarearrows.com/hc/inboxes',
  integrations: 'https://softwarearrows.com/hc/integrations',
  labels: 'https://softwarearrows.com/hc/labels',
  macros: 'https://softwarearrows.com/hc/macros',
  message_reply_to: 'https://softwarearrows.com/hc/reply-to',
  reports: 'https://softwarearrows.com/hc/reports',
  sla: 'https://softwarearrows.com/hc/sla',
  team_management: 'https://softwarearrows.com/hc/teams',
  webhook: 'https://softwarearrows.com/hc/webhooks',
  billing: 'https://softwarearrows.com/pricing',
};

export function getHelpUrlForFeature(featureName) {
  return FEATURE_HELP_URLS[featureName];
}
