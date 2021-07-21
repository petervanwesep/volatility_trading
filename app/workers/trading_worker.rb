require_relative "../../lib/client"

class TradingWorker
  include Sidekiq::Worker

  CHECK_FREQUENCY = Integer(ENV['CHECK_FREQUENCY'])

  def perform(*args)
    VolatilityTrading::Trader.run(symbol: "eth")
    TradingWorker.perform_in(CHECK_FREQUENCY.seconds)
  end
end
