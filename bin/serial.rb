require 'miner_mover'

CFG = {
  time_limit: 20, # seconds
  ore_limit: 100, # million

  depth: 30,
  miner_variance: 0,
  partial_reward: false,

  batch_size: 10, # million
  rate: 2,
  mover_work: :wait,
  mover_variance: 0,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

TIMER = CompSci::Timer.new.freeze

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

include MinerMover

miner = Miner.new(partial_reward: CFG[:partial_reward],
                  variance: CFG[:miner_variance],
                  logging: true,
                  timer: TIMER)
log "MINE Mining operation started  [ctrl-c] to stop"

mover = Mover.new(batch_size: CFG[:batch_size],
                  rate: CFG[:rate],
                  work_type: CFG[:mover_work],
                  variance: CFG[:mover_variance],
                  logging: true,
                  timer: TIMER)
log "MOVE Moving operation started"
log "WAIT Waiting for ore ..."

ore_mined = 0

# miner waits for the SIGINT signal to quit
while !stop_mining
  # mine the ore
  ore = miner.mine_ore(CFG[:depth])
  ore_mined += ore

  # load (and possibly move) the ore
  mover.load_ore ore if ore > 0

  # stop mining after a while
  if TIMER.elapsed > CFG[:time_limit] or
    Ore.block(ore_mined) > CFG[:ore_limit]
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
