require_relative "../../lib/trader"
class TradingWorker
  include Sidekiq::Worker

  CHECK_FREQUENCY = Integer(ENV['CHECK_FREQUENCY'])

  def perform(*args)
    time_to_run = 1.minute.from_now.beginning_of_minute
    VolatilityTrading::Trader.run
  ensure
    self.class.perform_at(time_to_run)
  end
end
