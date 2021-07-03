require 'date'
require 'pry'
require 'httparty'
require 'csv'

class Trader
  PERCENT_STEP = 0.02

  def self.loop
    # if holding
    #   current_bid := get current bid
    #   updated_threshold = current bid * (1 - PERCENT_STEP)
    #   if no current threshold
    #     current_threshold := updated_threshold
    #   else if current_bid > previous_bid
    #     current_threshold := updated_threshold
    #     Remove existing orders (should only be 1)
    #     Place stop order to sell all at current threshold
    #   previous_bid := current_bid
    # else (not holding)
    #   current_ask := get current ask
    #   updated_threshold = current ask * (1 + PERCENT_STEP)
    #   if no current threshold
    #     current_threshold := updated_threshold
    #   else if current_price < previous_price
    #     current_threshold := updated_threshold
    #     Remove existing orders (should only be 1)
    #     Place stop order to buy all at current threshold
    #   previous_ask := current_ask
  end
end

# Make a trade √
# Sell all √
# Buy all √
# Make a stop order for buy all
# Make a stop order for sell all
# Cancel all orders
# Make a stop order for buy all based on price
# Make a stop order for sell all based on price
# Make a stop order based on price direction and holdings
#

module Client
  class Private
    APPROXIMATE_ALL = 0.95

    def get_current_ask(symbol:)
      get_prices(symbol: symbol)[0]
    end

    def get_current_bid(symbol:)
      get_prices(symbol: symbol)[1]
    end

    def get_prices(symbol:)
      base_uri = "https://api.gemini.com/v2/ticker"
      response = HTTParty.get("#{base_uri}/#{symbol}usd")
      [Float(response["ask"]).round(2), Float(response["bid"]).round(2)]
    end

    def sell_all(symbol:)
      token_balance = Float(balances.find { |e| e["currency"].downcase == symbol.downcase }["available"])
      current_bid = get_current_bid(symbol: symbol).round(2)
      sell(
        symbol: "#{symbol}USD",
        amount: token_balance * APPROXIMATE_ALL,
        price: 0.01,
        type: "exchange stop limit",
        stop_price: current_bid
      )
    end

    def buy_all(symbol:)
      usd_balance = Float(balances.find { |e| e["currency"].downcase == "usd" }["available"])
      current_ask = get_current_ask(symbol: symbol).round(2)
      amount = ((usd_balance * APPROXIMATE_ALL) / current_ask).round(4)
      binding.pry
      buy(
        symbol: "#{symbol}USD",
        amount: amount,
        price: 2**16,
        type: "exchange stop limit",
        stop_price: current_ask
      )
    end

    def balances
      request("/v1/balances")
    end

    def buy(symbol:, amount:, price:, type:, stop_price:)
      place_order(
        symbol: symbol,
        amount: amount,
        price: (stop_price * 1.01).round(2),
        side: "sell",
        type: type,
        stop_price: stop_price,
      )
    end

    def sell(symbol:, amount:, price:, type:, stop_price:)
      place_order(
        symbol: symbol,
        amount: amount,
        price: (stop_price * 0.99).round(2),
        side: "sell",
        type: type,
        stop_price: stop_price,
      )
    end

    def place_order(symbol:, amount:, price:, side:, type:, stop_price:)
      request(
        "/v1/order/new",
        symbol: symbol,
        amount: amount,
        price: price,
        side: side,
        type: type,
        stop_price: stop_price,
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

    def cancel_orders
      # HTTParty.post(
      #   "/v1/order/cancel/session",
      #   query: {
      #     payload: {
      #       request: "/v1/order/cancel/session",
      #       nonce: nonce
      #     }
      #   },
      # )
    end

    def build_payload(params)
      params = params.merge(nonce: nonce).to_json
      Base64.encode64(params).gsub("\n", "")
    end

    def signature(encoded_payload)
      OpenSSL::HMAC.hexdigest("SHA384", ENV['GEMINI_API_SECRET'], encoded_payload)
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
        "X-GEMINI-APIKEY" => ENV["GEMINI_API_KEY"],
        "X-GEMINI-PAYLOAD" => encoded_payload,
        "X-GEMINI-SIGNATURE" => signature,
        "Cache-Control" => "no-cache",
      }
    end
  end
end

# public_client = Client::Public.new
# public_client.get_prices
# pp public_client



# To persist:
#   per token:
#     holding?
#     buy_limit
#     sell_limit
#
