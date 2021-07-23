require_relative "../../lib/price_checker"
require_relative "../../lib/portfolio"
class PriceCheckingWorker
  include Sidekiq::Worker

  def perform
    return unless ENV['CHECK_PRICES'] == 'true'

    next_run_time = 1.minute.from_now.beginning_of_minute

    VolatilityTrading::Portfolio.settings.keys.each do |symbol|
      next if symbol == 'usd'
      VolatilityTrading::PriceChecker.run(symbol: symbol)
    end
  ensure
    PriceCheckingWorker.perform_at(next_run_time)
  end
end