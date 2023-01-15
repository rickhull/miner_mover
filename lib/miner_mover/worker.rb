require 'miner_mover'
require 'miner_mover/timer'

module MinerMover
  def self.work(duration, type = :wait, fib_target = 30)
    case type
    when :wait
      sleep duration
      duration
    when :cpu
      t = Timer.new
      self.fib(fib_target) while t.elapsed < duration
      t.elapsed
    when :instant
      0
    else
      raise "unknown work type: #{type.inspect}"
    end
  end

  def self.fib n
    (n < 2) ?  n  :  fib(n-1) + fib(n-2)
  end

  class Worker
    attr_accessor :variance, :logging, :debugging
    attr_reader :timer

    def initialize(variance: 0, logging: false, debugging: false, timer: nil)
      @variance = variance
      @logging = logging
      @debugging = debugging
      @timer = timer || Timer.new
    end

    def id
      self.object_id.to_s.rjust(8, '0')
    end

    def state
      { id: self.id,
        logging: @logging,
        debugging: @debugging,
        timer: @timer.elapsed_ms.round,
        variance: @variance }
    end

    def to_s
      self.state.to_s
    end

    def log msg
      @logging and MinerMover.log @timer, self.id, msg
    end

    def debug msg
      @debugging and MinerMover.log @timer, self.id, msg
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
    attr_accessor :depth, :partial_reward

    def initialize(depth: 5,
                   partial_reward: false,
                   variance: 0,
                   logging: false,
                   debugging: false,
                   timer: nil)
      @partial_reward = partial_reward
      @depth = depth
      super(variance: variance, timer: timer,
            logging: logging, debugging: debugging)
    end

    def state
      super.merge(depth: @depth, partial_reward: @partial_reward)
    end

    # return an array of integers representing ore mined at each depth
    def mine_ores(depth = @depth)
      # every new depth is a new mining operation
      Array.new(depth) { |d|
        # mine ore by calculating fibonacci for that depth
        mined = MinerMover.fib(self.varied(d).round)
        @partial_reward ? rand(1 + mined) : mined
      }
    end

    # wrap the above method with logging, timing, and summing
    def mine_ore(depth = @depth)
      log format("MINE Depth %i", depth)
      ores, elapsed = Timer.elapsed { self.mine_ores(depth) }
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
                   debugging: false,
                   timer: nil)
      @batch_size = batch_size * Ore::BLOCK
      @rate = rate.to_f * Ore::BLOCK
      @work_type = work_type
      @batch, @batches, @ore_moved = 0, 0, 0
      super(variance: variance, timer: timer,
            logging: logging, debugging: debugging)
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

    # accept some ore for moving; just accumulate unless we have a full batch
    def load_ore amount
      log format("LOAD %s | %s", Ore.display(amount), self.status)
      @batch += amount
      move_batch if @batch >= @batch_size
      log format("LDED %s | %s", Ore.display(amount), self.status)
      @batch
    end

    # return the amount moved
    def move_batch
      raise "unexpected batch: #{@batch}" if @batch <= 0
      amount = [@batch, @batch_size].min

      self.move amount

      # accounting
      @ore_moved += amount
      @batch -= amount
      @batches += 1

      amount
    end

    # perform the work of moving the amount of ore
    def move amount
      duration = self.varied(amount / @rate)
      log format("MOVE %s (%.2f s)", Ore.display(amount), duration)
      _, elapsed = Timer.elapsed { MinerMover.work(duration, @work_type) }
      log format("MOVD %s (%.2f s)", Ore.display(amount), elapsed)
      self
    end
  end
end
