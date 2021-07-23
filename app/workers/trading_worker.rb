require_relative "../../lib/trader"
class TradingWorker
  include Sidekiq::Worker

  CHECK_FREQUENCY = Integer(ENV['CHECK_FREQUENCY'])

  def perform(*args)
    VolatilityTrading::Trader.run
  ensure
    TradingWorker.perform_in(CHECK_FREQUENCY.seconds)
  end
end
