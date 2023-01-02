require 'compsci/timer'
require 'compsci/fibonacci'

module MinerMover
  FIB_WORK = 30
  WORK_TYPES = [:cpu, :wait, :instant]

  def self.work(duration, type = :wait)
    case type
    when :wait
      sleep duration
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

  class Worker
    attr_reader :log, :work_type

    def initialize(work_type:)
      @work_type = work_type
      @log = []
    end

    def id
      self.object_id.to_s.rjust(8, '0')
    end

    def log_lines! &blk
      yield @log.shift until @log.empty?
    end

    def flush_log!
      str = @log.join("\n")
      @log.clear
      str
    end
  end

  class Miner < Worker
    attr_reader :random_difficulty, :random_reward

    def initialize(work_type: :cpu,
                   random_difficulty: true,
                   random_reward: true)
      super(work_type: work_type)
      @random_difficulty = random_difficulty
      @random_reward = random_reward
    end

    def to_s
      [self.id,
       @work_type,
       "rd:#{@random_difficulty}",
       "rr:#{@random_reward}"
      ].join(' ')
    end

    def mine_ore(depth = 1)
      ores, elapsed = CompSci::Timer.elapsed {
        Array.new(depth) { |d|
          depth_factor = 1 + d * 0.5
          difficulty = @random_difficulty ? (0.5 + rand) : 1
          MinerMover.work(difficulty * depth_factor, @work_type)
          @random_reward ? rand(1 + depth_factor.floor) : 1
        }
      }
      total = ores.sum
      @log << format("MINE %s %s %i ore (%.2f s)",
                     self.id, ores.inspect, total, elapsed)
      total
    end
  end

  class Mover < Worker
    attr_reader :batch, :batch_size, :batches, :ore_moved

    def initialize(batch_size, work_type: :cpu, random_duration: true)
      super(work_type: work_type)
      @batch_size = batch_size
      @random_duration = random_duration
      @batch, @batches, @ore_moved = 0, 0, 0
    end

    def to_s
      [self.id,
       "Batch %i / %i" % [@batch, @batch_size],
       "Moved %i (%i)" % [@batches, @ore_moved]].join(' | ')
    end

    def load_ore(amt)
      @batch += amt
      move_batch if @batch >= @batch_size
      @batch
    end

    def move_batch
      raise "unexpected batch: #{@batch}" if @batch <= 0
      amt = @batch < @batch_size ? @batch : @batch_size
      duration = @random_duration ? (rand(amt) + 1) : amt

      _, elapsed = CompSci::Timer.elapsed {
        MinerMover.work(duration, @work_type)
      }
      @log << format("MOVE %s %i ore (%.1f s)", self.id, amt, elapsed)

      # accounting
      @ore_moved += amt
      @batch -= amt
      @batches += 1

      # what we moved
      amt
    end
  end
end
