module MinerMover
  # $/ is the default line separator: "\n"
  def self.puts(str, separator = $/)
    $stdout.write_nonblock(str + separator)
  end

  # called by Worker instances, available for general use
  def self.log_fmt(timer, id, msg)
    format("%s %s %s", timer.elapsed_display, id, msg)
  end

  def self.log(timer, id, msg)
    self.puts self.log_fmt(timer, id, msg)
  end

  # i +- 50% at squeeze 0
  # i +- 25% at squeeze 1, 12.5% at squeeze 2, etc.
  def self.randomize(i, squeeze = 0)
    r, base = rand, 0.5
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

    # raw ore in, blocks out
    def self.block(ore, size = BLOCK)
      ore.to_f / size
    end

    # mostly used for display purposes
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

    # entirely used for display purposes
    def self.display(ore)
      format("%s ore", self.units(ore))
    end
  end
end
