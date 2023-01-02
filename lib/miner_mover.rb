require 'miner_mover/timer'

class MinerMover
  def self.perform_io(duration)
    sleep duration
  end

  def self.perform_work(duration)
    t = Timer.new
    fib(32) while t.elapsed < duration
    t.elapsed
  end

  def self.fib(n)
    n < 2 ? n : fib(n-1) + fib(n-2)
  end

  def self.mine_ore(depth = 1,
                    perform_work: false,
                    random_difficulty: true,
                    random_reward: true)
    t = Timer.new
    ores = Array.new(depth) { |d|
      depth_factor = 1 + d * 0.5
      difficulty = random_reward ? (0.5 + rand) : 1
      duration = difficulty * depth_factor
      perform_work ? perform_work(duration) : perform_io(duration)
      random_reward ? rand(1 + depth_factor.floor) : 1
    }
    puts format("%s MINE %s (duration)", t.elapsed_display, ores.inspect)
    ores.sum
  end

  attr_reader :batch, :batch_size, :batches, :ore_moved

  def initialize(batch_size, perform_work: false, random_duration: true)
    @batch_size = batch_size
    @perform_work = perform_work
    @random_duration = random_duration
    @batch, @batches, @ore_moved = 0, 0, 0
  end

  def to_s
    [self.object_id.to_s.rjust(8, '0'),
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

    puts format("%s MOVE %i ore (duration)",
                Timer.elapsed_display(duration * 1000), amt)
    @perform_work ?
      MinerMover.perform_work(duration) :
      MinerMover.perform_io(duration)

    # accounting
    @ore_moved += amt
    @batch -= amt
    @batches += 1

    # what we moved
    amt
  end
end
