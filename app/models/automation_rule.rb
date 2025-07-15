# == Schema Information
#
# Table name: automation_rules
#
#  id           :bigint           not null, primary key
#  actions      :jsonb            not null
#  active       :boolean          default(TRUE), not null
#  conditions   :jsonb            not null
#  description  :text
#  event_name   :string           not null
#  name         :string           not null
#  phone_number :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  inbox_id     :bigint
#  template_id  :bigint
#
# Indexes
#
#  index_automation_rules_on_account_id   (account_id)
#  index_automation_rules_on_inbox_id     (inbox_id)
#  index_automation_rules_on_template_id  (template_id)
#
class AutomationRule < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Reauthorizable

  belongs_to :account
  has_many_attached :files

  validate :json_conditions_format
  validate :json_actions_format
  validate :query_operator_presence
  validate :query_operator_value
  validates :account_id, presence: true
  validates :phone_number, format: { with: /\A\+\d{10,15}\z/, message: 'must be a valid international number' }, allow_nil: true

  after_update_commit :reauthorized!, if: -> { saved_change_to_conditions? }
  before_validation :normalize_rating_value_for_csat, if: -> { event_name == 'csat_response_created' }

  scope :active, -> { where(active: true) }

  # Define standard condition attributes for most events
  def conditions_attributes
    %w[content email country_code status message_type browser_language assignee_id team_id referer city company inbox_id
       mail_subject phone_number priority conversation_language]
  end

  # Define CSAT-specific condition attributes
  def csat_conditions_attributes
    %w[rating]
  end

  def actions_attributes
    %w[send_message add_label remove_label send_email_to_team assign_team assign_agent send_webhook_event mute_conversation
       send_attachment change_status resolve_conversation open_conversation snooze_conversation change_priority send_email_transcript].freeze
  end

  def file_base_data
    files.map do |file|
      {
        id: file.id,
        automation_rule_id: id,
        file_type: file.content_type,
        account_id: account_id,
        file_url: url_for(file),
        blob_id: file.blob_id,
        filename: file.filename.to_s
      }
    end
  end

  private

  def normalize_rating_value_for_csat
    return if conditions.blank?

    self.conditions = conditions.map do |condition|
      if condition['attribute_key'] == 'rating' &&
         condition['values'].is_a?(Array) &&
         condition['values'].all? { |v| v.is_a?(String) || v.is_a?(Integer) }

        condition['values'] = condition['values'].map(&:to_i)
      end
      condition
    end
  end

  def json_conditions_format
    return if conditions.blank?

    Rails.logger.debug { "Validating conditions for event: #{event_name}, conditions: #{conditions.inspect}" }

    # Determine valid attributes based on event_name
    valid_attributes = case event_name
                       when 'csat_response_created'
                         csat_conditions_attributes
                       else
                         conditions_attributes
                       end

    # Add custom attributes to the valid list
    valid_attributes += account.custom_attribute_definitions.pluck(:attribute_key)

    # Check for unsupported attributes
    attributes = conditions.map { |obj| obj['attribute_key'] }
    unsupported = attributes - valid_attributes

    return unless unsupported.any?

    errors.add(:conditions, "Automation conditions #{unsupported.join(',')} not supported for event #{event_name}.")
  end

  def json_actions_format
    return if actions.blank?

    attributes = actions.map { |obj| obj['action_name'] }
    unsupported = attributes - actions_attributes

    return unless unsupported.any?

    errors.add(:actions, "Automation actions #{unsupported.join(',')} not supported.")
  end

  def query_operator_presence
    return if conditions.blank?

    operators = conditions.select { |obj| obj['query_operator'].nil? }
    return unless operators.length > 1

    errors.add(:conditions, 'Automation conditions should have query operator.')
  end

  def query_operator_value
    conditions.each do |obj|
      validate_single_condition(obj)
    end
  end

  def validate_single_condition(condition)
    query_operator = condition['query_operator']

    return if query_operator.nil? || query_operator.empty?

    operator = query_operator.upcase
    return if %w[AND OR].include?(operator)

    errors.add(:conditions, 'Query operator must be either "AND" or "OR"')
  end
end

AutomationRule.include_mod_with('Audit::AutomationRule')
AutomationRule.prepend_mod_with('AutomationRule')
