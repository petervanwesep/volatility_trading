require 'date'
require 'pry'
require 'httparty'
require 'csv'
require_relative './mailer'

module VolatilityTrading
  class Trader
    PERCENT_STEP = Float(ENV.fetch("PERCENT_STEP"))

    def self.run
      client = Client::Private.new
      current_threshold = Redis.current.get("current_threshold")
      current_threshold = Float(current_threshold) if current_threshold.present?
      current_bid = client.get_current_bid(symbol: "eth")
      current_ask = client.get_current_ask(symbol: "eth")

      if client.holding?(symbol: "eth")
        updated_threshold = (current_bid * (1 - PERCENT_STEP)).round(2)
        Rails.logger.info "Price: $#{current_bid}. Threshold: #{current_threshold}. Holding..."

        if !current_threshold
          Rails.logger.info "ACTION - Setting current threshold to $#{updated_threshold}..."
          Redis.current.set("current_threshold", updated_threshold)
        elsif current_bid <= current_threshold
          Rails.logger.info "ACTION - Current bid of $#{current_bid} is less than current threshold of $#{current_threshold}... Selling it all!!!"
          client.sell_all(symbol: "eth")
          Mailer.trade_report(price: current_bid, side: 'sell')
          Redis.current.del("current_threshold")
        else # current_bid > current_threshold
          if updated_threshold > current_threshold
            Rails.logger.info "ACTION - Updated threshold is more than current threshold. Resetting threshold to $#{updated_threshold}..."
            Redis.current.set("current_threshold", updated_threshold)
            Mailer.threshold_reset(price: current_bid, current_threshold: updated_threshold)
          end
        end
      else # Not Holding
        updated_threshold = (current_ask * (1 + PERCENT_STEP)).round(2)
        Rails.logger.info "Price: $#{current_ask}. Threshold: #{current_threshold}. Not holding..."

        if !current_threshold
          Rails.logger.info "ACTION - Setting current threshold to $#{updated_threshold}..."
          Redis.current.set("current_threshold", updated_threshold)
        elsif current_ask >= current_threshold
          Rails.logger.info "ACTION - Current ask of $#{current_ask} is greater than current threshold of $#{current_threshold}... Buying it all!!!"
          client.buy_all(symbol: "eth")
          Mailer.trade_report(price: current_ask, side: 'buy')
          Redis.current.del("current_threshold")
        else # current_ask < current_threshold
          if updated_threshold < current_threshold
            Rails.logger.info "ACTION - Updated threshold is less than current threshold. Resetting threshold to $#{updated_threshold}..."
            Redis.current.set("current_threshold", updated_threshold)
            Mailer.threshold_reset(price: current_ask, current_threshold: updated_threshold)
          end
        end
      end
    end
  end
  module Client
    class Private
      APPROXIMATE_ALL = Float(ENV.fetch('APPROXIMATE_ALL'))
      MINIMUM_TOKEN_AMOUNT = Float(ENV.fetch('MINIMUM_TOKEN_AMOUNT'))

      def holding?(symbol:)
        token_balance = Float(balances.find { |e| e["currency"].downcase == symbol.downcase }["available"])
        token_balance > MINIMUM_TOKEN_AMOUNT
      end

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
          amount: (token_balance * APPROXIMATE_ALL).round(4),
          price: current_bid,
          type: "exchange limit",
        )
      end

      def buy_all(symbol:)
        usd_balance = Float(balances.find { |e| e["currency"].downcase == "usd" }["available"])
        current_ask = get_current_ask(symbol: symbol).round(2)
        amount = ((usd_balance * APPROXIMATE_ALL) / current_ask)
        buy(
          symbol: "#{symbol}USD",
          amount: amount.round(4),
          price: current_ask,
          type: "exchange limit",
        )
      end

      def balances
        request("/v1/balances")
      end

      def buy(symbol:, amount:, price:, type:)
        p place_order(
          symbol: symbol,
          amount: amount,
          price: (price * 1.01).round(2),
          side: "buy",
          type: type,
        )
      end

      def sell(symbol:, amount:, price:, type:)
        p place_order(
          symbol: symbol,
          amount: amount,
          price: (price * 0.99).round(2),
          side: "sell",
          type: type,
        )
      end

      def place_order(symbol:, amount:, price:, side:, type:)
        request(
          "/v1/order/new",
          symbol: symbol,
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
end
