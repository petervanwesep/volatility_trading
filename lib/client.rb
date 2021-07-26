require 'date'
require 'pry'
require 'httparty'
require 'csv'
require_relative './mailer'
require_relative './portfolio'
module VolatilityTrading
  class Client
    APPROXIMATE_ALL = Float(ENV.fetch('APPROXIMATE_ALL'))

    attr_reader :symbol

    def initialize(symbol:)
      @symbol = symbol
    end

    def minimum_token_amount
      @minimum_token_amount ||= Portfolio.settings[symbol][:minimum_holding]
    end

    def token_balance
      balance = balances.find { |e| e.symbol == symbol.downcase }
      balance ? balance.amount : 0
    end

    def usd_balance
      Float(balances.find { |e| e.symbol == "usd" }.amount)
    end

    def holding?
      token_balance > minimum_token_amount
    end

    def current_ask
      @current_ask ||= get_current_ask.round(4)
    end

    def current_bid
      @current_bid ||= get_current_bid.round(4)
    end

    def get_current_ask
      get_prices[0]
    end

    def get_current_bid
      get_prices[1]
    end

    def price
      base_uri = "https://api.gemini.com/v1/pricefeed"
      Float(HTTParty.get(base_uri).find { |e| e["pair"] == "#{symbol.upcase}USD" }["price"])
    end

    def get_prices
      base_uri = "https://api.gemini.com/v2/ticker"
      response = HTTParty.get("#{base_uri}/#{symbol}usd")
      [Float(response["ask"]), Float(response["bid"])]
    end

    def percent_of_portfolio
      Portfolio.read[symbol][:percent]
    end

    def sell_all!
      sell(
        amount: token_balance * APPROXIMATE_ALL,
        price: current_bid,
      )
    end

    def buy_all!
      buy(
        amount: (usd_to_buy / current_ask),
        price: current_ask,
      )
    end

    def usd_to_buy
      held_assets = balances.select(&:holding)
      unheld_assets = Portfolio.settings.delete_if { |e| held_assets.map(&:symbol).include?(e) }
      total_percentage = unheld_assets.values.map { |e| e[:percent] }.sum
      return 0 unless Portfolio.settings[symbol].present?
      percent_to_buy = Portfolio.settings[symbol][:percent] / total_percentage
      (usd_balance * APPROXIMATE_ALL * percent_to_buy)
    end

    class TokenBalance
      attr_reader :symbol, :amount, :holding

      def initialize(symbol:, amount:, holding:)
        @symbol = symbol
        @amount = amount
        @holding = holding
      end
    end

    def balances
      response = request("/v1/balances")
      JSON.parse(response.body)
        .map do |e|
          next unless e.is_a?(Hash) && Portfolio.settings[e["currency"].downcase].present?
          TokenBalance.new(
            symbol: e["currency"].downcase,
            amount: Float(e["amount"]),
            holding: Float(e["amount"]) > Portfolio.settings[e["currency"].downcase][:minimum_holding]
          )
        end
        .compact
    end

    def buy(amount:, price:)
      place_order(
        amount: amount,
        price: (price * 1.005).round(2),
        side: "buy",
      )
    end

    def sell(amount:, price:)
      place_order(
        amount: amount,
        price: (price * 0.995).round(2),
        side: "sell",
      )
    end

    def order_status(order_id:)
      request(
        "/v1/order/status",
        order_id: order_id,
        include_trades: true,
      )
    end



    def place_order(amount:, price:, side:)
      response = p request(
        "/v1/order/new",
        symbol: "#{symbol}USD",
        amount: amount.round(4),
        price: price,
        side: side,
        type: 'exchange limit',
        options: ['immediate-or-cancel'],
      )

      if response.success?
        status_response = order_status(order_id: response["order_id"])

        Order.create!(
          external_id: response["order_id"],
          symbol: status_response["symbol"],
          amount: status_response["executed_amount"],
          price: status_response["avg_execution_price"],
          side: status_response["side"],
          fee: Float(status_response.dig("trades", 0, "fee_amount") || 0).round(2),
        )
      end

      response
    end

    def request(path, payload={})
      headers = build_headers(payload.merge(request: path))
      HTTParty.post("#{base_url}#{path}", query: nil, headers: headers)
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
