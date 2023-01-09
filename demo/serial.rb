require 'miner_mover/run'

include MinerMover

run = Run.new.cfg_banner!(sleep_duration = 1)
run.timer.timestamp!
run.log "Starting"

stop_mining = false
Signal.trap("INT") {
  run.timer.timestamp!
  run.log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

# system 'cpulimit', "--pid=#{Process.pid}", '--limit=1', '--background'

miner = run.new_miner
run.log "MINE Mining operation initialized  [ctrl-c] to stop"

mover = run.new_mover
run.log "MOVE Moving operation initialized"

ore_mined = 0

# miner waits for the SIGINT signal to quit
while !stop_mining
  # mine the ore
  ore = miner.mine_ore
  ore_mined += ore

  # load (and possibly move) the ore
  mover.load_ore ore if ore > 0

  # stop mining after a while
  if run.timer.elapsed > run.time_limit or Ore.block(ore_mined) > run.ore_limit
    run.timer.timestamp!
    miner.log format("Mining limit reached: %s", Ore.display(ore_mined))
    stop_mining = true
  end
end

# miner has quit; move any remaining ore and quit
mover.move_batch while mover.batch > 0
run.log "QUIT #{mover.status}"

ore_moved = mover.ore_moved
run.log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)
run.log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
run.timer.timestamp!
