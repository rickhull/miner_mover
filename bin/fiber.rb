require 'miner_mover'

CFG = {
  num_miners: 1,   # unused
  mining_depth: 3,
  miner_work_type: :cpu,
  random_difficulty: true,
  random_reward: true,

  num_movers: 1,   # unused
  batch_size: 5,
  mover_work_type: :cpu,
  random_duration: true,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

TIMER = CompSci::Timer.new.freeze

def log(msg)
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

miner = Fiber.new(blocking: true) {
  m = MinerMover::Miner.new(work_type: CFG[:miner_work_type],
                            timer: TIMER,
                            random_difficulty: CFG[:random_difficulty],
                            random_reward: CFG[:random_reward])
  m.log "MINE Miner started"

  ore_mined = 0

  # miner waits for the SIGINT signal to quit
  while !stop_mining
    ore = m.mine_ore(CFG[:mining_depth])

    # send any ore mined to the mover
    Fiber.yield ore if ore > 0
    ore_mined += ore
  end

  m.log "MINE Miner finished after mining #{ore_mined} ore"
  Fiber.yield :quit
  ore_mined
}
log "MINE Mining operation started  [ctrl-c] to stop"


mover = MinerMover::Mover.new(CFG[:batch_size],
                              timer: TIMER,
                              work_type: CFG[:mover_work_type],
                              random_duration: CFG[:random_duration])
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
log "QUIT #{mover}"

log "MINE #{miner.resume} ore mined"
log "MOVE #{mover.ore_moved} ore moved"
TIMER.timestamp!
