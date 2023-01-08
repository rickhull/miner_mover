require 'miner_mover/run'

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

# miner runs in its own Fiber
miner = Fiber.new(blocking: true) {
  log "MINE Mining operation started  [ctrl-c] to stop"
  m = Miner.new(**MINER)

  ore_mined = 0

  # miner waits for the SIGINT signal to quit
  while !stop_mining
    ore = m.mine_ore DEPTH

    # send any ore mined to the mover
    Fiber.yield ore if ore > 0
    ore_mined += ore

    # stop mining after a while
    if TIMER.elapsed > TIME_LIMIT or Ore.block(ore_mined) > ORE_LIMIT
      TIMER.timestamp!
      m.log format("Mining limit reached: %s", Ore.display(ore_mined))
      stop_mining = true
    end
  end

  m.log format("MINE Miner finished after mining %s", Ore.display(ore_mined))
  Fiber.yield :quit
  ore_mined
}

mover = Mover.new(**MOVER)
log "MOVE Moving operation started"
log "WAIT Waiting for ore ..."

loop {
  # pick up ore yielded by the miner
  ore = miner.resume
  break if ore == :quit

  # load (and possibly move) the ore
  mover.load_ore ore if ore > 0
}

# miner has quit; move any remaining ore and quit
mover.move_batch while mover.batch > 0
log "QUIT #{mover.status}"

ore_mined = miner.resume
ore_moved = mover.ore_moved
log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)
log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
TIMER.timestamp!
