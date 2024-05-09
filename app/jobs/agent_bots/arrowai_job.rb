class AgentBots::ArrowaiJob < ApplicationJob
  queue_as :high

  def perform(event, agent_bot, message)
    Integrations::Arrowai::ProcessorService.new(
      event_name: event, agent_bot: agent_bot, message: message
    ).perform
  end
end
