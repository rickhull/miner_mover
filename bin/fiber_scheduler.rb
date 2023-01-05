require 'miner_mover/run'
require 'fiber_scheduler'

include MinerMover

TIMER = CompSci::Timer.new.freeze

cfg_file = ARGV.shift || Config.recent
cfg_file ? puts("USING: #{cfg_file}") :  raise("no config file available")

pp CFG = Config.process(cfg_file)
MAIN = CFG.fetch(:main)
DEPTH = MAIN.fetch(:mining_depth)
TIME_LIMIT = MAIN.fetch(:time_limit)
ORE_LIMIT = MAIN.fetch(:ore_limit)
NUM_MINERS = MAIN.fetch(:num_miners)
NUM_MOVERS = MAIN.fetch(:num_movers)
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

queue = Thread::Queue.new
total_mined = 0
total_moved = 0

FiberScheduler do
  miners = Array.new(NUM_MINERS) { |i|
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

        # cooperative yield, don't hog
        sleep 0
      end

      m.log format("MINE Miner #{i} finished after mining %s",
                   Ore.display(ore_mined))
      total_mined += ore_mined
    end
  }

  movers = Array.new(NUM_MOVERS) { |i|
    Fiber.schedule do

      m = Mover.new(**MOVER)
      m.log "MOVE Mover #{i} started"

      while !queue.closed?
        # pick up ore from the miner
        ore = queue.pop

        # load (and possibly move) the ore
        m.load_ore ore if ore > 0

        # cooperative yield, don't hog
        sleep 0
      end

      # miners have quit; move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m.status}"
      total_moved += m.ore_moved
    end
  }

  Fiber.schedule do
    sleep 0.1 while miners.all?(&:alive?)
    queue.close
  end
end

log format("MINE %s mined (%i)", Ore.display(total_mined), total_mined)
log format("MOVE %s moved (%i)", Ore.display(total_moved), total_moved)
TIMER.timestamp!
