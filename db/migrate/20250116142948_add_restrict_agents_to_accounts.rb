class AddRestrictAgentsToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :restrict_agents, :boolean, default: false
  end
end
