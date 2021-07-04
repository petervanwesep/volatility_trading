require_relative "../../lib/client"

class TradingWorker
  include Sidekiq::Worker

  def perform(*args)
    Trader.run
    TradingWorker.perform_in(3.seconds)
  end
end
