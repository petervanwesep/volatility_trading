require "net/https"
require "uri"
require 'net/smtp'

module VolatilityTrading
  class Mailer
    attr_accessor :to, :from, :subject, :text

    def initialize(params={})
      @to      = params[:to]
      @from    = params[:from]
      @subject = params[:subject]
      @text    = params[:text]
    end

    def self.threshold_reset(price:, current_threshold:)
      new(
        to: 'petervanwesep@gmail.com',
        from: 'volatilitytrader@gmail.com',
        subject: "Threshold reset",
        text: "ETH now at $#{price}. Threshold reset to $#{current_threshold}."
      ).deliver!
    end

    def self.trade_report(price:, side:)
      new(
        to: 'petervanwesep@gmail.com',
        from: 'volatilitytrader@gmail.com',
        subject: "#{side.capitalize} has been executed",
        text: "Sold all ETH at $#{price}."
      ).deliver!
    end

    def deliver!
      Net::SMTP.start(
        ENV['MAILGUN_SMTP_SERVER'],
        ENV['MAILGUN_SMTP_PORT'],
        ENV['MAILGUN_DOMAIN'],
        ENV['MAILGUN_SMTP_LOGIN'],
        ENV['MAILGUN_SMTP_PASSWORD'],
        :plain
      ) do |smtp|
        msgstr = """
        From: Volatility Trader <volatilitytrader@gmail.com>
        To: #{@to}
        Subject: #{@subject}
        Date: #{Time.current.to_s}

        #{@text}
        """

        smtp.send_message msgstr, "volatilitytrader@gmail.com", @to
      end
    end
  end
end
