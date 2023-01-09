require 'miner_mover/run'
require 'fiber_scheduler'

include MinerMover

TIMER = CompSci::Timer.new.freeze

cfg_file = ARGV.shift || Config.recent || raise("no config file")
puts "USING: #{cfg_file}"
pp CFG = Config.process(cfg_file)
sleep 1

# pre-fetch all the values we'll need
MAIN = CFG.fetch :main
DEPTH      = MAIN.fetch :mining_depth
TIME_LIMIT = MAIN.fetch :time_limit
ORE_LIMIT  = MAIN.fetch :ore_limit
NUM_MINERS = MAIN.fetch :num_miners
NUM_MOVERS = MAIN.fetch :num_movers

# freeze the rest
MINER = CFG.fetch(:miner).merge(logging: true, timer: TIMER).freeze
MOVER = CFG.fetch(:mover).merge(logging: true, timer: TIMER).freeze

def log msg
  puts MinerMover.log_fmt(TIMER, ' (main) ', msg)
end

TIMER.timestamp!
log "Starting"

stop_mining = false
Signal.trap("INT") {
  TIMER.timestamp!
  log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

# for moving ore
queue = Thread::Queue.new

# for signalling between miners and supervisor
mutex = Mutex.new
cond = ConditionVariable.new

# for getting results from scheduled fibers
mined = Thread::Queue.new
moved = Thread::Queue.new

# follow the rabbit
FiberScheduler do

  # several miners, stored in an array
  miners = Array.new(NUM_MINERS) { |i|

    # each miner gets a fiber
    Fiber.schedule do
      m = Miner.new(**MINER)
      m.log "MINE Miner #{i} started"

      ore_mined = 0

      # miner waits for the SIGINT signal to quit
      while !stop_mining
        ore = m.mine_ore DEPTH

        # send any ore mined to the mover
        queue.push(ore) if ore > 0
        ore_mined += ore

        # stop mining after a while
        if TIMER.elapsed > TIME_LIMIT or Ore.block(ore_mined) > ORE_LIMIT
          TIMER.timestamp!
          m.log format("Mining limit reached: %s", Ore.display(ore_mined))
          stop_mining = true
        end
      end

      m.log format("MINE Miner #{i} finished after mining %s",
                   Ore.display(ore_mined))

      # accumulate ore mined (nonblocking fiber can't return a value)
      mined.push ore_mined
      mutex.synchronize { cond.signal }
    end
  }

  # several movers, no need to store
  NUM_MOVERS.times { |i|

    # each mover gets a fiber
    Fiber.schedule do
      m = Mover.new(**MOVER)
      m.log "MOVE Mover #{i} started"

      loop {
        # pick up ore from the miner until we get a :quit message
        ore = queue.pop
        break if ore == :quit

        # load (and possibly move) the ore
        m.load_ore ore if ore > 0
      }

      # miners have quit; move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m.status}"

      # register the ore moved (scheduled fiber can't return a value)
      moved.push m.ore_moved
    end
  }

  # supervisor waits for the miners to quit and signals the movers
  # to quit by pushing :quit into the queue
  Fiber.schedule do
    mutex.synchronize { cond.wait(mutex) while miners.any?(&:alive?) }
    NUM_MOVERS.times { queue.push(:quit) }
    queue.close # should helpfully cause errors if anything is out of sync
  end
end

total_mined = 0
total_mined += mined.pop until mined.empty?

total_moved = 0
total_moved += moved.pop until moved.empty?

log format("MINE %s mined (%i)", Ore.display(total_mined), total_mined)
log format("MOVE %s moved (%i)", Ore.display(total_moved), total_moved)
TIMER.timestamp!
