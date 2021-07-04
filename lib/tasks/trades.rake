namespace :trades do
  desc "Kick off trading loop"
  task loop: :environment do
    TradingWorker.perform_async
  end
end