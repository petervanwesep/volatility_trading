require_relative "../../lib/client"

class TradingWorker
  include Sidekiq::Worker

  CHECK_FREQUENCY = Integer(ENV['CHECK_FREQUENCY'])

  def perform(*args)
    Trader.run
    TradingWorker.perform_in(CHECK_FREQUENCY.seconds)
  end
end
