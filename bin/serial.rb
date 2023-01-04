require 'miner_mover'

CFG = {
  time_limit: 20, # seconds
  ore_limit: 100, # million

  mining_depth: 30,
  random_difficulty: false,
  random_reward: false,

  batch_size: 10, # million
  mover_work: :wait,
  random_duration: false,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

TIMER = CompSci::Timer.new.freeze

def log msg
  puts MinerMover.log(TIMER, ' (main) ', msg)
end

TIMER.timestamp!
log "Starting"

stop_mining = false

Signal.trap("INT") {
  TIMER.timestamp!
  log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

miner = MinerMover::Miner.new(timer: TIMER,
                              logging: true,
                              random_difficulty: CFG[:random_difficulty],
                              random_reward: CFG[:random_reward])
log "MINE Mining operation started  [ctrl-c] to stop"

mover = MinerMover::Mover.new(CFG[:batch_size],
                              timer: TIMER,
                              logging: true,
                              work_type: CFG[:mover_work],
                              random_duration: CFG[:random_duration])
log "MOVE Moving operation started"
log "WAIT Waiting for ore ..."

ore_mined = 0

# miner waits for the SIGINT signal to quit
while !stop_mining
  # mine the ore
  ore = miner.mine_ore(CFG[:mining_depth])
  ore_mined += ore

  # load (and possibly move) the ore
  mover.load_ore ore if ore > 0

  # stop mining after a while
  if TIMER.elapsed > CFG[:time_limit] or
    MinerMover.block(ore_mined) > CFG[:ore_limit]
    TIMER.timestamp!
    miner.log format("Mining limit reached: %s",
                     MinerMover.display_block(ore_mined))
    stop_mining = true
  end
end

# miner has quit; move any remaining ore and quit
mover.move_batch while mover.batch > 0
log "QUIT #{mover}"

ore_moved = mover.ore_moved
log format("MINE %s mined (%i)",
           MinerMover.display_block(ore_mined), ore_mined)
log format("MOVE %s moved (%i)",
           MinerMover.display_block(ore_moved), ore_moved)
TIMER.timestamp!
