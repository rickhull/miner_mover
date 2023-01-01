class MinerMover
  def self.perform_io(duration)
    sleep duration
  end

  def self.perform_work(duration)
    t = Time.now
    elapsed = 0
    while elapsed < duration
      fib(32)
      elapsed = Time.now - t
    end
    Time.now - t
  end

  def self.fib(n)
    n < 2 ? n : fib(n-1) + fib(n-2)
  end

  def self.mine_ore(depth = 1, perform_work: false)
    t = Time.now
    ores = Array.new(depth) { |d|
      depth_factor = 1 + d * 0.5
      difficulty = 0.5 + rand
      duration = difficulty * depth_factor
      perform_work ? perform_work(duration) : perform_io(duration)
      rand(1 + depth_factor.floor)
    }
    elapsed = (Time.now - t).round(2)
    puts "#{elapsed} s #{ores.inspect}"
    ores.sum
  end

  attr_reader :batch, :batch_size, :batches, :ore_moved

  def initialize(batch_size, perform_work: false)
    @batch_size = batch_size
    @perform_work = perform_work
    @batch, @batches, @ore_moved = 0, 0, 0
  end

  def load_ore(amt)
    @batch += amt
    move_batch if @batch >= @batch_size
    @batch
  end

  def move_batch
    raise "unexpected batch: #{@batch}" if @batch <= 0
    amt = @batch < @batch_size ? @batch : @batch_size
    duration = rand(amt) + 1
    # duration = 10
    puts "Moving #{amt} (#{duration} s) ..."
    @perform_work ? MinerMover.perform_work(duration) : MinerMover.perform_io(duration)

    # accounting
    @ore_moved += amt
    @batch -= amt
    @batches += 1

    # what we moved
    amt
  end
end
