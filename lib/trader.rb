require_relative './client'
require_relative './engine'

module VolatilityTrading
  class Trader
    def self.run
      Portfolio.settings.keys.each do |symbol|
        next if symbol == 'usd'

        client = Client.new(symbol: symbol)
        engine = Engine.new(symbol: symbol)

        engine.update_threshold!

        if engine.time_to_sell?
          Rails.logger.info "ACTION - Current bid of $#{client.current_bid} is less than current threshold of $#{engine.current_threshold}... Selling all the #{symbol}!!!"
          client.sell_all!
        elsif engine.time_to_buy?
          Rails.logger.info "ACTION - Current ask of $#{client.current_ask} is greater than current threshold of $#{engine.current_threshold}... Buying all the #{symbol}!!!"
          client.buy_all!
        else
          holding_text = client.holding? ? "Holding" : "Not holding"
          if Time.current.to_i % 100 == 0
            Rails.logger.info "#{symbol.upcase} price: $#{client.current_bid}. Threshold: #{engine.current_threshold}. #{holding_text} #{symbol.upcase}..."
          end
        end
      end
    end
  end
end