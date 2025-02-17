require 'administrate/field/base'

class Enterprise::AccountLimitsField < Administrate::Field::Base
  def to_s
    data.present? ? data.to_json : { agents: 6, inboxes: 5 }.to_json
  end
end
