class CreateOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :orders do |t|
      t.string :external_id, null: false
      t.string :symbol, null: false
      t.decimal :amount, null: false
      t.decimal :price, null: false
      t.string :side, null: false
      t.decimal :fee, null: false, default: 0
      t.timestamps
    end
  end
end
