class V2::Reports::ContactSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  def build
    set_grouped_conversations_count
    prepare_report
  end

  private

  def set_grouped_conversations_count
    @grouped_conversations_count = Current.account.conversations.where(created_at: range).group('contact_id').count
  end

  def group_by_key
    'conversations.contact_id'
  end

  def prepare_report
    account.contacts.each_with_object([]) do |contact, arr|
      arr << {
        id: contact.id,
        conversations_count: @grouped_conversations_count[contact.id]
      }
    end
  end
end
