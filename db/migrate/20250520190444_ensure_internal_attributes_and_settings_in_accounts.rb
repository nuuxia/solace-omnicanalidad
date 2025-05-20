class EnsureInternalAttributesAndSettingsInAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :internal_attributes, :jsonb, null: false, default: {} unless column_exists?(:accounts, :internal_attributes)

    return if column_exists?(:accounts, :settings)

    add_column :accounts, :settings, :jsonb, default: {}
  end
end
