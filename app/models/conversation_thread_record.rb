# == Schema Information
#
# Table name: conversation_thread_records
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  assistant_id    :string
#  conversation_id :bigint           not null
#  thread_id       :string
#
# Indexes
#
#  index_conversation_thread_records_on_conversation_id  (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#
class ConversationThreadRecord < ApplicationRecord
  belongs_to :conversation
end
