require 'miner_mover/run'

include MinerMover

TIMER = CompSci::Timer.new.freeze

cfg_file = ARGV.shift || Config.recent
cfg_file ? puts("USING: #{cfg_file}") :  raise("no config file available")

pp CFG = Config.process(cfg_file)
MAIN = CFG.fetch(:main)
DEPTH = MAIN.fetch(:mining_depth)
TIME_LIMIT = MAIN.fetch(:time_limit)
ORE_LIMIT = MAIN.fetch(:ore_limit)
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

# system 'cpulimit', "--pid=#{Process.pid}", '--limit=1', '--background'

miner = Miner.new(**MINER)
log "MINE Mining operation initialized  [ctrl-c] to stop"

mover = Mover.new(**MOVER)
log "MOVE Moving operation initialized"

ore_mined = 0

# miner waits for the SIGINT signal to quit
while !stop_mining
  # mine the ore
  ore = miner.mine_ore DEPTH
  ore_mined += ore

  # load (and possibly move) the ore
  mover.load_ore ore if ore > 0

  # stop mining after a while
  if TIMER.elapsed > TIME_LIMIT or Ore.block(ore_mined) > ORE_LIMIT
    TIMER.timestamp!
    miner.log format("Mining limit reached: %s", Ore.display(ore_mined))
    stop_mining = true
  end
end

# miner has quit; move any remaining ore and quit
mover.move_batch while mover.batch > 0
log "QUIT #{mover.status}"

ore_moved = mover.ore_moved
log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)
log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
TIMER.timestamp!
