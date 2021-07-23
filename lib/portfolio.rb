module VolatilityTrading
  module Portfolio
    def self.settings
      JSON.parse(File.read("lib/portfolio.json")).with_indifferent_access
    end
  end
end