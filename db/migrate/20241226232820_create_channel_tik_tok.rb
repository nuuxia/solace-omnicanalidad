class CreateChannelTikTok < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_tik_tok do |t|
      t.references :account, null: false, foreign_key: true
      t.string :tik_tok_access_token
      t.string :tik_tok_refresh_token
      t.string :tik_tok_user_id
      t.datetime :tik_tok_token_expires_at
      t.datetime :tok_tok_refresh_expires_at
      t.timestamps
    end
  end
end
