class CampaignsCsvWhatsappPolicy < ApplicationPolicy
  %i[index? show? create? update? destroy? retry?].each do |m|
    define_method(m) { @account_user.administrator? }
  end
end
