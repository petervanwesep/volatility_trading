require 'date'
require 'pry'
require 'httparty'
require 'csv'
require_relative './mailer'

module VolatilityTrading
  PERCENT_STEP = Float(ENV.fetch("PERCENT_STEP"))
  THRESHOLD_KEY = "current_threshold"
  class Trader

    def self.run(symbol:)
      client = Client.new(symbol: symbol)
      engine = Engine.new(symbol: symbol)

      engine.update_threshold!

      if engine.time_to_sell?
        Rails.logger.info "ACTION - Current bid of $#{client.current_bid} is less than current threshold of $#{engine.current_threshold}... Selling it all!!!"
        client.sell_all!
      elsif engine.time_to_buy?
        Rails.logger.info "ACTION - Current ask of $#{client.current_ask} is greater than current threshold of $#{engine.current_threshold}... Buying it all!!!"
        client.buy_all!
      else
        Rails.logger.info "Price: $#{client.current_bid}. Threshold: #{engine.current_threshold}. Holding..."
      end
    end
  end

  class Engine
    THRESHOLD_WINDOW = Integer(ENV.fetch("THRESHOLD_WINDOW")) || 60

    def initialize(symbol:)
      @client = Client.new(symbol: symbol)
      @holding = @client.holding?
    end

    def clear_threshold!
      Redis.current.del(THRESHOLD_KEY)
    end

    def update_threshold!
      last_order_at = Time.at(Integer(Redis.current.get("last_action") || 0))
      recent_prices = TokenPrice.where("checked_at > ?", [THRESHOLD_WINDOW.minutes.ago, last_order_at].max).map(&:price)
      extremum = @holding ? recent_prices.max : recent_prices.min

      return unless extremum

      updated_threshold = @holding ?
        (extremum * (1 - PERCENT_STEP)).round(2) :
        (extremum * (1 + PERCENT_STEP)).round(2)

      Redis.current.set(THRESHOLD_KEY, updated_threshold)
    end

    def current_threshold
      current_threshold = Redis.current.get(THRESHOLD_KEY)
      Float(current_threshold) if current_threshold.present?
    end

    def time_to_sell?
      @client.holding? && @client.current_bid <= current_threshold
    end

    def time_to_buy?
      !@client.holding? && @client.current_ask >= current_threshold
    end
  end

  class Client
    APPROXIMATE_ALL = Float(ENV.fetch('APPROXIMATE_ALL'))
    MINIMUM_TOKEN_AMOUNT = Float(ENV.fetch('MINIMUM_TOKEN_AMOUNT'))

    attr_reader :symbol

    def initialize(symbol:)
      @symbol = symbol
    end

    def holding?
      token_balance = Float(balances.find { |e| e["currency"].downcase == symbol.downcase }["available"])
      token_balance > MINIMUM_TOKEN_AMOUNT
    end

    def current_ask
      @current_ask ||= get_current_ask
    end

    def current_bid
      @current_bid ||= get_current_bid
    end

    def get_current_ask
      get_prices[0]
    end

    def get_current_bid
      get_prices[1]
    end

    def get_prices
      base_uri = "https://api.gemini.com/v2/ticker"
      response = HTTParty.get("#{base_uri}/#{symbol}usd")
      [Float(response["ask"]).round(2), Float(response["bid"]).round(2)]
    end

    def sell_all!
      token_balance = Float(balances.find { |e| e["currency"].downcase == symbol.downcase }["available"])
      current_bid = get_current_bid.round(2)
      sell(
        pair: "#{symbol}USD",
        amount: (token_balance * APPROXIMATE_ALL).round(4),
        price: current_bid,
        type: "exchange limit",
      )
    end

    def buy_all!
      usd_balance = Float(balances.find { |e| e["currency"].downcase == "usd" }["available"])
      current_ask = get_current_ask.round(2)
      amount = ((usd_balance * APPROXIMATE_ALL) / current_ask)
      buy(
        pair: "#{symbol}USD",
        amount: amount.round(4),
        price: current_ask,
        type: "exchange limit",
      )
    end

    def balances
      request("/v1/balances")
    end

    def buy(pair:, amount:, price:, type:)
      p place_order(
        pair: pair,
        amount: amount,
        price: (price * 1.001).round(2),
        side: "buy",
        type: type,
      )
    end

    def sell(pair:, amount:, price:, type:)
      p place_order(
        pair: pair,
        amount: amount,
        price: (price * 0.999).round(2),
        side: "sell",
        type: type,
      )
    end

    def place_order(pair:, amount:, price:, side:, type:)
      Redis.current.set("last_order", Time.current.to_i)

      request(
        "/v1/order/new",
        symbol: pair,
        amount: amount,
        price: price,
        side: side,
        type: type,
      )
    end

    def request(path, payload={})
      headers = build_headers(payload.merge(request: path))
      HTTParty.post(
        "#{base_url}#{path}",
        query: nil,
        headers: headers,
      )
    end

    def build_payload(params)
      params = params.merge(nonce: nonce).to_json
      Base64.encode64(params).gsub("\n", "")
    end

    def signature(encoded_payload)
      OpenSSL::HMAC.hexdigest("SHA384", ENV.fetch('GEMINI_API_SECRET'), encoded_payload)
    end

    def base_url
      "https://api.gemini.com"
    end

    def nonce
      DateTime.now.strftime('%Q')
    end

    def build_headers(payload)
      encoded_payload = build_payload(payload)
      signature = signature(encoded_payload)

      {
        "Content-Length" => "0",
        "Content-Type" => "text/plain",
        "X-GEMINI-APIKEY" => ENV.fetch("GEMINI_API_KEY"),
        "X-GEMINI-PAYLOAD" => encoded_payload,
        "X-GEMINI-SIGNATURE" => signature,
        "Cache-Control" => "no-cache",
      }
    end
  end
end
