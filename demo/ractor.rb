require 'miner_mover/run'
require 'thread'

include MinerMover

TIMER = CompSci::Timer.new.freeze
DEBUG = false

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

# the moving operation executes in its own Ractor
mover = Ractor.new {
  log "MOVE Moving operation started"

  # use queue to distribute incoming ore to mover threads
  queue = Thread::Queue.new

  # store the mover threads in an array
  movers = Array.new(NUM_MOVERS) { |i|
    Thread.new {
      m = Mover.new(**MOVER)
      m.log "MOVE Mover #{i} started"

      loop {
        # a mover picks up ore from the queue
        DEBUG && m.log("POP ")
        ore = queue.pop
        DEBUG && m.log("POPD #{ore}")

        break if ore == :quit

        # load (and possibly move) the ore
        m.load_ore ore
      }

      # move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m.status}"
      m
    }
  }

  # Miners feed this Ractor with ore
  # Pass the ore into a queue for the movers
  # When the miners say to quit, tell the movers to quit
  log "WAIT Waiting for ore ..."
  loop {
    # when the Ractor gets ore, push it into the queue
    ore = Ractor.recv
    DEBUG && log("RECV #{ore}")

    break if ore == :quit

    DEBUG && log("PUSH #{ore}")
    queue.push ore
    DEBUG && log("PSHD #{ore}")
  }

  # tell all the movers to quit and gather their results
  NUM_MOVERS.times { queue.push :quit }
  movers.map { |thr| thr.value.ore_moved }.sum
}

# our mining operation executes in the main Ractor, here
log "MINE Mining operation started  [ctrl-c] to stop"

# store the miner threads in an array
miners = Array.new(NUM_MINERS) { |i|
  Thread.new {
    m = Miner.new(**MINER)
    m.log "MINE Miner #{i} started"
    ore_mined = 0

    # miners wait for the SIGINT signal to quit
    while !stop_mining
      ore = m.mine_ore DEPTH

      # send any ore mined to the mover Ractor
      if ore > 0
        DEBUG && m.log("SEND #{ore}")
        mover.send ore
        DEBUG && m.log("SENT #{ore}")
      end

      ore_mined += ore

      # stop mining after a while
      if TIMER.elapsed > TIME_LIMIT or Ore.block(ore_mined) > ORE_LIMIT
        TIMER.timestamp!
        m.log format("Mining limit reached: %s", Ore.display(ore_mined))
        stop_mining = true
      end
    end

    m.log format("MINE Miner %i finished after mining %s",
                 i, Ore.display(ore_mined))
    ore_mined
  }
}

# wait on all mining threads to stop
ore_mined = miners.map { |thr| thr.value }.sum
log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)

# tell mover to quit
mover.send :quit

# wait for results
ore_moved = mover.take
log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
TIMER.timestamp!
