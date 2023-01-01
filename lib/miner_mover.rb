class MinerMover
  def self.mine_ore(depth = 1)
    t = Time.now
    ores = Array.new(depth) { |d|
      depth_factor = 1 + d * 0.5
      difficulty = 0.5 + rand
      duration = difficulty * depth_factor
      sleep duration
      rand(1 + depth_factor.floor)
    }
    elapsed = (Time.now - t).round(2)
    puts "#{elapsed} s #{ores.inspect}"
    ores.sum
  end

  attr_reader :batch, :batch_size, :batches, :ore_moved

  def initialize(batch_size)
    @batch_size = batch_size
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
    sleep duration # move, move, move

    # accounting
    @ore_moved += amt
    @batch -= amt
    @batches += 1

    # what we moved
    amt
  end
end
