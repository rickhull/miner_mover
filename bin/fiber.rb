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

miner = Fiber.new(blocking: true) {
  m = Miner.new(partial_reward: CFG[:partial_reward],
                variance: CFG[:miner_variance],
                logging: true,
                timer: TIMER)
  m.log "MINE Miner started"

  ore_mined = 0

  # miner waits for the SIGINT signal to quit
  while !stop_mining
    ore = m.mine_ore(CFG[:depth])

    # send any ore mined to the mover
    Fiber.yield ore if ore > 0
    ore_mined += ore

    # stop mining after a while
    if TIMER.elapsed > CFG[:time_limit] or
      Ore.block(ore_mined) > CFG[:ore_limit]
      TIMER.timestamp!
      m.log format("Mining limit reached: %s", Ore.display(ore_mined))
      stop_mining = true
    end
  end

  m.log format("MINE Miner finished after mining %s",
               Ore.display(ore_mined))
  Fiber.yield :quit
  ore_mined
}
log "MINE Mining operation started  [ctrl-c] to stop"


mover = Mover.new(batch_size: CFG[:batch_size],
                  rate: CFG[:rate],
                  work_type: CFG[:mover_work],
                  variance: CFG[:mover_variance],
                  logging: true,
                  timer: TIMER)
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
