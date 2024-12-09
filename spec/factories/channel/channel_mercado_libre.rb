# frozen_string_literal: true

FactoryBot.define do
  factory :channel_mercado_libre, class: 'Channel::MercadoLibre' do
    association :account
    sequence(:mercado_libre_user_id) { |n| n + 1000 }
    mercado_libre_access_token { 'APP_USR-2830702889377861-112611-d54d03368691c36de6e94ca26c579d78-2063720151' }
    mercado_libre_refresh_token { 'TG-6745e6572f7e4d00018d1153-2063720151' }
    mercado_libre_token_expires_at { 1.hour.from_now }

    after(:create) do |channel_mercado_libre|
      create(:inbox, channel: channel_mercado_libre, account: channel_mercado_libre.account)
    end
  end
end
