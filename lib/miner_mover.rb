require 'compsci/timer'
require 'compsci/fibonacci'

module MinerMover
  FIB_WORK = 30

  def self.work(duration, type = :wait)
    case type
    when :wait
      sleep duration
      duration
    when :cpu
      t = CompSci::Timer.new
      CompSci::Fibonacci.classic(FIB_WORK) while t.elapsed < duration
      t.elapsed
    when :instant
      0
    else
      raise "unknown work type: #{type.inspect}"
    end
  end

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

  class Worker
    attr_accessor :variance, :logging
    attr_reader :timer

    def initialize(variance: 0, logging: false, timer: nil)
      @variance = variance
      @logging = logging
      @timer = timer || CompSci::Timer.new
    end

    def id
      self.object_id.to_s.rjust(8, '0')
    end

    def state
      { id: self.id,
        logging: @logging,
        timer: @timer.elapsed_ms.round,
        variance: @variance }
    end

    def to_s
      self.state.to_s
    end

    def log msg
      @logging && puts(MinerMover.log_fmt(@timer, self.id, msg))
    end

    # 4 levels:
    # 0 - no variance
    # 1 - 12.5% variance (squeeze = 2)
    # 2 - 25%   variance (squeeze = 1)
    # 3 - 50%   variance (squeeze = 0)
    def varied n
      case @variance
      when 0
        n
      when 1..3
        MinerMover.randomize(n, 3 - @variance)
      else
        raise "unexpected variance: #{@variance.inspect}"
      end
    end
  end

  class Miner < Worker
    attr_accessor :partial_reward

    def initialize(partial_reward: true,
                   variance: 0,
                   logging: false,
                   timer: nil)
      @partial_reward = partial_reward
      super(variance: variance, logging: logging, timer: timer)
    end

    def state
      super.merge(partial_reward: @partial_reward)
    end

    def mine_ore(depth = 1)
      log format("MINE Depth %i", depth)
      ores, elapsed = CompSci::Timer.elapsed {
        Array.new(depth) { |d|
          mined = CompSci::Fibonacci.classic(self.varied(d))
          @partial_reward ? rand(1 + mined) : mined
        }
      }
      total = ores.sum
      log format("MIND %s %s (%.2f s)",
                 Ore.display(total), ores.inspect, elapsed)
      total
    end
  end

  class Mover < Worker
    attr_reader :rate, :work_type, :batch, :batch_size, :batches, :ore_moved

    def initialize(batch_size: 10,
                   rate: 2,  # 2M ore per sec
                   work_type: :cpu,
                   variance: 0,
                   logging: false,
                   timer: nil)
      @batch_size = batch_size * Ore::BLOCK
      @rate = rate.to_f * Ore::BLOCK
      @work_type = work_type
      @batch, @batches, @ore_moved = 0, 0, 0
      super(variance: variance, logging: logging, timer: timer)
    end

    def state
      super.merge(work_type: @work_type,
                  batch_size: @batch_size,
                  batch: @batch,
                  batches: @batches,
                  ore_moved: @ore_moved)
    end

    def status
      [format("Batch %s / %s %i%%",
              Ore.units(@batch),
              Ore.units(@batch_size),
              @batch.to_f * 100 / @batch_size),
       format("Moved %ix (%s)", @batches, Ore.units(@ore_moved)),
      ].join(' | ')
    end

    def load_ore(amt)
      @batch += amt
      move_batch if @batch >= @batch_size
      log format("LOAD %s", self.status)
      @batch
    end

    def move_batch
      raise "unexpected batch: #{@batch}" if @batch <= 0
      amt = [@batch, @batch_size].min
      duration = self.varied(amt / @rate)

      log format("MOVE %s (%.1f s)", Ore.display(amt), duration)
      _, elapsed = CompSci::Timer.elapsed {
        MinerMover.work(duration, @work_type)
      }
      log format("MOVD %s (%.1f s)", Ore.display(amt), elapsed)

      # accounting
      @ore_moved += amt
      @batch -= amt
      @batches += 1

      # what we moved
      amt
    end
  end
end
