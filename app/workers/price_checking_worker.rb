require_relative "../../lib/client"
class PriceCheckingWorker
  include Sidekiq::Worker

  def perform(symbol="eth")
    return unless ENV['CHECK_PRICES'] == 'true'

    next_run_time = 1.minute.from_now.beginning_of_minute

    client = VolatilityTrading::Client::Private.new
    current_bid = client.get_current_bid(symbol: symbol)
    current_ask = client.get_current_ask(symbol: symbol)

    return unless current_bid && current_ask

    TokenPrice.create!(symbol: symbol, price: ((current_bid + current_ask)/ 2).round(2))
    PriceCheckingWorker.perform_at(next_run_time)
  end
end