module MinerMover
  def self.log_fmt(timer, id, msg)
    format("%s %s %s", timer.elapsed_display, id, msg)
  end

  def self.randomize(i, squeeze = 0)
    r = rand
    base = 0.5
    # every squeeze, increase the base closer to 1 and cut the rand in half
    squeeze.times { |s|
      r *= 0.5
      base += 0.5 ** (s+2)
    }
    i * (base + r)
  end

  # ore is handled in blocks of 1M
  module Ore
    BLOCK = 1_000_000

    def self.block(ore, size = BLOCK)
      ore.to_f / size
    end

    def self.units(ore)
      if ore % BLOCK == 0 or ore > BLOCK * 100
        format("%iM", self.block(ore).round)
      elsif ore > BLOCK
        format("%.2fM", self.block(ore))
      elsif ore > 10_000
        format("%iK", self.block(ore, 1_000).round)
      else
        format("%i", ore)
      end
    end

    def self.display(ore)
      format("%s ore", self.units(ore))
    end
  end
end
