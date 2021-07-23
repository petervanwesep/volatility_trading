require_relative './client'

module VolatilityTrading
  class Engine
    THRESHOLD_WINDOW = Integer(ENV.fetch("THRESHOLD_WINDOW")) || 60
    PERCENT_STEP = Float(ENV.fetch("PERCENT_STEP"))
    THRESHOLD_KEY = "current_threshold"

    attr_reader :client, :holding

    def initialize(symbol:)
      @symbol = symbol
      @client = Client.new(symbol: symbol)
      @holding = client.holding?
      @threshold_key = "#{THRESHOLD_KEY}_#{symbol}"
    end

    def clear_threshold!
      Redis.current.del(@threshold_key)
    end

    def update_threshold!
      last_order_at = Time.at(Integer(Redis.current.get("last_action_#{@symbol}") || 0))
      recent_prices = TokenPrice
        .where(symbol: @symbol)
        .where("checked_at > ?", [THRESHOLD_WINDOW.minutes.ago, last_order_at].max).map(&:price)

      extremum = holding ? recent_prices.max : recent_prices.min
      extremum = client.current_bid unless extremum # In case we haven't recorded prices

      return unless extremum

      updated_threshold = holding ? (extremum * (1 - PERCENT_STEP)) : (extremum * (1 + PERCENT_STEP))

      Redis.current.set(@threshold_key, updated_threshold)
    end

    def current_threshold
      current_threshold = Redis.current.get(@threshold_key)
      update_threshold! unless current_threshold
      Float(current_threshold) if current_threshold.present?
    end

    def time_to_sell?
      client.holding? && client.current_bid < current_threshold
    end

    def time_to_buy?
      !client.holding? && client.current_ask > current_threshold
    end
  end
end