class UpdateDefaultTimestamp < ActiveRecord::Migration[6.1]
  def up
    remove_column :token_prices, :checked_at
    add_column :token_prices, :checked_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
