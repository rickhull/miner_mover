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

# system 'cpulimit', "--pid=#{Process.pid}", '--limit=1', '--background'

miner = run.new_miner
run.log "MINE Mining operation initialized  [ctrl-c] to stop"

mover = run.new_mover
run.log "MOVE Moving operation initialized"
ore_mined = 0

while !stop_mining # SIGINT will trigger stop_mining = true
  ore = miner.mine_ore
  ore_mined += ore
  mover.load_ore ore if ore > 0 # move_batch happens when a batch is full

  # stop mining after a while
  if run.time_limit? or run.ore_limit?(ore_mined)
    run.timestamp!
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
run.timestamp!
