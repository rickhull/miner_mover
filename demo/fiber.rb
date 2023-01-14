require 'miner_mover/run'

include MinerMover

run = Run.new.cfg_banner!(duration: 1).start!
run.timestamp!
run.log "Starting"

stop_mining = false
Signal.trap("INT") {
  run.timestamp!
  run.log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

# miner runs in its own Fiber
miner = Fiber.new(blocking: true) {
  run.log "MINE Mining operation started  [ctrl-c] to stop"
  m = run.new_miner
  ore_mined = 0

  while !stop_mining # SIGINT will trigger stop_mining = true
    ore = m.mine_ore
    ore_mined += ore
    Fiber.yield ore if ore > 0

    # stop mining after a while
    if run.time_limit? or run.ore_limit?(ore_mined)
      run.timestamp!
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

# mover pulls from the queue, loads the ore, and moves it
loop {
  ore = miner.resume
  break if ore == :quit
  mover.load_ore ore if ore > 0 # move_batch happens when a batch is full
}

# move any remaining ore and quit
mover.move_batch while mover.batch > 0
run.log "QUIT #{mover.status}"

ore_mined = miner.resume
ore_moved = mover.ore_moved
run.log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)
run.log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
run.timestamp!
