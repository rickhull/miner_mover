require 'miner_mover/run'
require 'thread'

include MinerMover

run = Run.new.cfg_banner!(duration: 1).start!
run.timestamp!
run.log "Starting #{__FILE__}"

stop_mining = false
Signal.trap("INT") {
  run.timestamp!
  run.log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

run.log "MOVE Moving operation started"
queue = Thread::Queue.new
run.log "WAIT Waiting for ore ..."

# store mover threads in an array
movers = Array.new(run.num_movers) { |i|
  Thread.new {
    m = run.new_mover
    run.log "MOVE Mover #{i} started"

    # movers pull from the queue, load the ore, and move it
    loop {
      ore = queue.pop
      break if ore == :quit
      m.load_ore ore # moving of ore possibly happens here (on a full batch)
    }

    # move any remaining ore and quit
    m.move_batch while m.batch > 0
    m.log "QUIT #{m.status}"
    m
  }
}


run.log "MINE Mining operation started  [ctrl-c] to stop"

# store the miner threads in an array
miners = Array.new(run.num_miners) { |i|
  Thread.new {
    m = run.new_miner
    m.log "MINE Miner #{i} started"
    ore_mined = 0

    # miners wait for the SIGINT signal to quit
    while !stop_mining
      ore = m.mine_ore
      ore_mined += ore
      queue.push ore if ore > 0 # send any ore mined to the movers

      # stop mining after a while
      if run.time_limit? or run.ore_limit?(ore_mined)
        run.timestamp!
        m.log format("Mining limit reached: %s", Ore.display(ore_mined))
        stop_mining = true
      end
    end

    m.log format("MINE Miner %i finished after mining %s",
                 i, Ore.display(ore_mined))
    ore_mined
  }
}

# wait on all mining threads to stop
ore_mined = miners.map { |thr| thr.value }.sum
run.log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)

# tell all the movers to quit; gather their results
run.num_movers.times { queue.push :quit }

# wait for results
ore_moved = movers.map { |thr| thr.value.ore_moved }.sum
run.log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
run.timestamp!
