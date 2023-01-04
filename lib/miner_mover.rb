require 'compsci/timer'
require 'compsci/fibonacci'

module MinerMover
  FIB_WORK = 30
  ORE_BLOCK = 1_000_000

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

  def self.block(ore, size = ORE_BLOCK)
    ore.to_f / size
  end

  def self.display_block(ore)
    if ore % ORE_BLOCK == 0 or ore > ORE_BLOCK * 100
      format("%iM ore", self.block(ore).round)
    elsif ore > ORE_BLOCK
      format("%.2fM ore", self.block(ore))
    elsif ore > 10_000
      format("%iK ore", self.block(ore, 1_000).round)
    else
      format("%i ore", ore)
    end
  end

  class Worker
    attr_reader :timer
    attr_accessor :logging

    def initialize(timer: nil, logging: false)
      @timer = timer || CompSci::Timer.new
      @logging = logging
    end

    def id
      self.object_id.to_s.rjust(8, '0')
    end

    def log msg
      @logging && puts(MinerMover.log(@timer, self.id, msg))
    end
  end

  class Miner < Worker
    attr_reader :random_difficulty, :random_reward

    def initialize(timer: nil,
                   logging: false,
                   random_difficulty: false,
                   random_reward: true)
      super(timer: timer, logging: logging)
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
          random_target = ((0.5 + rand) * d).round
          target = @random_difficulty ? random_target : d
          ore = [CompSci::Fibonacci.classic(target), 1].max
          random_ore = rand(1 + ore)
          @random_reward ? random_ore : ore
        }
      }
      total = ores.sum
      log format("MIND %s %s (%.2f s)",
                 MinerMover.display_block(total), ores.inspect, elapsed)
      total
    end
  end

  class Mover < Worker
    RATE = 2 * ORE_BLOCK # ore/sec baseline

    attr_reader :batch, :batch_size, :batches, :ore_moved

    def initialize(batch_size,
                   timer: nil,
                   logging: false,
                   work_type: :cpu,
                   random_duration: true)
      @batch_size = batch_size * ORE_BLOCK
      super(timer: timer, logging: logging)
      @work_type = work_type
      @random_duration = random_duration
      @batch, @batches, @ore_moved = 0, 0, 0
    end

    def to_s
      [self.id,
       format("Batch %s / %s %i%%",
              MinerMover.display_block(@batch),
              MinerMover.display_block(@batch_size),
              @batch.to_f * 100 / @batch_size),
       format("Moved %ix (%s)",
              @batches, MinerMover.display_block(@ore_moved)),
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
      amt = [@batch, @batch_size].min
      duration = amt / RATE
      duration = 1 + rand(duration) if @random_duration

      log format("MOVE %s (%.1f s)", MinerMover.display_block(amt), duration)
      _, elapsed = CompSci::Timer.elapsed {
        MinerMover.work(duration, @work_type)
      }
      log format("MOVD %s (%.1f s)", MinerMover.display_block(amt), elapsed)

      # accounting
      @ore_moved += amt
      @batch -= amt
      @batches += 1

      # what we moved
      amt
    end
  end
end
