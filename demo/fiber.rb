require 'miner_mover/run'

include MinerMover

run = Run.new.cfg_banner!(duration: 1)
run.timer.timestamp!
run.log "Starting"

stop_mining = false
Signal.trap("INT") {
  run.timer.timestamp!
  run.log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

# miner runs in its own Fiber
miner = Fiber.new(blocking: true) {
  run.log "MINE Mining operation started  [ctrl-c] to stop"
  m = run.new_miner

  ore_mined = 0

  # miner waits for the SIGINT signal to quit
  while !stop_mining
    ore = m.mine_ore

    # send any ore mined to the mover
    Fiber.yield ore if ore > 0
    ore_mined += ore

    # stop mining after a while
    if run.time_limit? or run.ore_limit?(ore_mined)
      run.timer.timestamp!
      m.log format("Mining limit reached: %s", Ore.display(ore_mined))
      stop_mining = true
    end
  end

  m.log format("MINE Miner finished after mining %s", Ore.display(ore_mined))
  Fiber.yield :quit
  ore_mined
}

mover = run.new_mover
run.log "MOVE Moving operation started"
run.log "WAIT Waiting for ore ..."

loop {
  # pick up ore yielded by the miner
  ore = miner.resume
  break if ore == :quit

  # load (and possibly move) the ore
  mover.load_ore ore if ore > 0
}

# miner has quit; move any remaining ore and quit
mover.move_batch while mover.batch > 0
run.log "QUIT #{mover.status}"

ore_mined = miner.resume
ore_moved = mover.ore_moved
run.log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)
run.log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
run.timer.timestamp!
