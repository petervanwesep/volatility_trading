require_relative "../lib/client"

module VolatilityTrading
  module PriceChecker
    def self.run(symbol:)
      client = VolatilityTrading::Client.new(symbol: symbol)
      current_bid = client.get_current_bid
      current_ask = client.get_current_ask

      return unless current_bid && current_ask

      TokenPrice.create!(symbol: symbol, price: ((current_bid + current_ask)/ 2))
    end
  end
end