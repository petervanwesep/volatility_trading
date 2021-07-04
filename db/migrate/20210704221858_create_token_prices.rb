class CreateTokenPrices < ActiveRecord::Migration[6.1]
  def change
    create_table :token_prices do |t|
      t.string :symbol, null: false
      t.decimal :price, null: false
      t.datetime :checked_at, null: false, default: -> { "'NOW'" }
    end
  end
end
