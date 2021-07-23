class CreateTokenBalance < ActiveRecord::Migration[6.1]
  def change
    create_table :token_balances do |t|
      t.string :token, null: false
      t.decimal :balance, null: false
      t.decimal :most_recent_usd_value, null: false
      t.timestamps
    end
  end
end
