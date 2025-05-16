# == Schema Information
#
# Table name: channel_tik_tok
#
#  id                         :bigint           not null, primary key
#  tik_tok_access_token       :string
#  tik_tok_refresh_token      :string
#  tik_tok_token_expires_at   :datetime
#  tok_tok_refresh_expires_at :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  tik_tok_user_id            :string
#
# Indexes
#
#  index_channel_tik_tok_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Channel::TikTok < ApplicationRecord
  include Channelable

  self.table_name = 'channel_tik_tok'

  belongs_to :account

end
