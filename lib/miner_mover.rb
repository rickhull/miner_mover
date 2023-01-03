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

  def self.log(timer, id, msg)
    format("%s %s %s", timer.elapsed_display, id, msg)
  end

  class Worker
    attr_reader :timer
    attr_accessor :log

    def initialize(timer: nil, log: false)
      @timer = timer || CompSci::Timer.new
      @log = log
    end

    def id
      self.object_id.to_s.rjust(8, '0')
    end

    def log msg
      @log && puts(MinerMover.log(@timer, self.id, msg))
    end
  end

  class Miner < Worker
    attr_reader :random_difficulty, :random_reward

    def initialize(timer: nil,
                   log: false,
                   random_difficulty: true,
                   random_reward: true)
      super(timer: timer, log: log)
      @random_difficulty = random_difficulty
      @random_reward = random_reward
    end

    def to_s
      [self.id,
       "rd:#{@random_difficulty}",
       "rr:#{@random_reward}"
      ].join(' ')
    end

    def mine_ore(depth = 1)
      log format("MINE Depth %i", depth)
      ores, elapsed = CompSci::Timer.elapsed {
        Array.new(depth) { |d|
          difficulty = @random_difficulty ? (0.5 + rand) : 1
          ore = [CompSci::Fibonacci.classic(difficulty * d), 1].max
          @random_reward ? rand(1 + ore) : ore
        }
      }
      total = ores.sum
      if total < 20_000
        total_display = format("%.2fK ore", total.to_f / 1_000)
      else
        total_display = format("%.2fM ore", total.to_f / 1_000_000)
      end
      log format("MIND %s %s (%.2f s)",
                 total_display, ores.inspect, elapsed)
      total
    end
  end

  class Mover < Worker
    UNIT = 1_000_000 # deal with blocks of 1M ore
    RATE = 10 * UNIT # ore/sec baseline

    attr_reader :batch, :batch_size, :batches, :ore_moved

    def initialize(batch_size,
                   timer: nil,
                   log: false,
                   work_type: :cpu,
                   random_duration: true)
      @batch_size = batch_size * UNIT
      super(timer: timer, log: log)
      @work_type = work_type
      @random_duration = random_duration
      @batch, @batches, @ore_moved = 0, 0, 0
    end

    def to_s
      [self.id,
       format("Batch %.2fM / %iM %.1f%%",
              @batch.to_f / UNIT,
              @batch_size / UNIT,
              @batch.to_f * 100 / @batch_size),
       format("Moved %ix (%.2fM)", @batches, @ore_moved.to_f / UNIT),
      ].join(' | ')
    end

    def load_ore(amt)
      @batch += amt
      move_batch if @batch >= @batch_size
      log format("LOAD %s", self.to_s)
      @batch
    end

    def move_batch
      raise "unexpected batch: #{@batch}" if @batch <= 0
      if @batch < @batch_size
        amt = @batch
        if @batch < 20_000
          display_amt = format("%.2fK ore", amt.to_f / 1_000)
        else
          display_amt = format("%.2fM ore", amt.to_f / UNIT)
        end
      else
        amt = @batch_size
        display_amt = format("%iM ore", amt / UNIT)
      end

      duration = amt / RATE
      duration = 1 + rand(duration) if @random_duration

      log format("MOVE %s (%.1f s)", display_amt, duration)
      _, elapsed = CompSci::Timer.elapsed {
        MinerMover.work(duration, @work_type)
      }
      log format("MOVD %s (%.1f s)", display_amt, elapsed)

      # accounting
      @ore_moved += amt
      @batch -= amt
      @batches += 1

      # what we moved
      amt
    end
  end
end
