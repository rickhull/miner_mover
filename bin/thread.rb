require 'miner_mover/run'
require 'thread'

include MinerMover

TIMER = CompSci::Timer.new.freeze
DEBUG = false

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

log "MOVE Moving operation started"
q = Thread::Queue.new
log "WAIT Waiting for ore ..."

movers = Array.new(NUM_MOVERS) { |i|
  Thread.new {
    m = Mover.new(**MOVER)
    log "MOVE Mover #{i} started"

    loop {
      # a mover picks up mined ore from the queue
      DEBUG && m.log("POP ")
      ore = q.pop
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


log "MINE Mining operation started  [ctrl-c] to stop"
miners = Array.new(NUM_MINERS) { |i|
  Thread.new {
    m = Miner.new(**MINER)
    m.log "MINE Miner #{i} started"
    ore_mined = 0

    # miners wait for the SIGINT signal to quit
    while !stop_mining
      ore = m.mine_ore DEPTH

      # send any ore mined to the movers
      if ore > 0
        DEBUG && m.log("PUSH #{ore}")
        q.push ore
        DEBUG && m.log("PSHD #{ore}")
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

# tell all the movers to quit; gather their results
NUM_MOVERS.times { q.push :quit }
ore_moved = movers.map { |thr| thr.value.ore_moved }.sum
log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)

TIMER.timestamp!
