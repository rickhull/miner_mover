require 'miner_mover/run'
require 'thread'

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

# the moving operation executes in its own Ractor
mover = Ractor.new(run) { |r|
  r.log "MOVE Moving operation started"

  # use queue to distribute incoming ore to mover threads
  queue = Thread::Queue.new

  # store the mover threads in an array
  movers = Array.new(r.num_movers) { |i|
    Thread.new {
      m = r.new_mover
      m.log "MOVE Mover #{i} started"

      loop {
        # a mover picks up ore from the queue
        r.debug && m.log("POP ")
        ore = queue.pop
        r.debug && m.log("POPD #{ore}")

        break if ore == :quit

        # load (and possibly move) the ore
        m.load_ore ore
      }

      # move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m.status}"
      m
    }
  }

  # Miners feed this Ractor with ore
  # Pass the ore into a queue for the movers
  # When the miners say to quit, tell the movers to quit
  r.log "WAIT Waiting for ore ..."
  loop {
    # when the Ractor gets ore, push it into the queue
    ore = Ractor.recv
    r.debug && r.log("RECV #{ore}")

    break if ore == :quit

    r.debug && r.log("PUSH #{ore}")
    queue.push ore
    r.debug && r.log("PSHD #{ore}")
  }

  # tell all the movers to quit and gather their results
  r.num_movers.times { queue.push :quit }
  movers.map { |thr| thr.value.ore_moved }.sum
}

# our mining operation executes in the main Ractor, here
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

      # send any ore mined to the mover Ractor
      if ore > 0
        run.debug && m.log("SEND #{ore}")
        mover.send ore
        run.debug && m.log("SENT #{ore}")
      end

      ore_mined += ore

      # stop mining after a while
      if run.timer.elapsed > run.time_limit or
        Ore.block(ore_mined) > run.ore_limit
        run.timer.timestamp!
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

# tell mover to quit
mover.send :quit

# wait for results
ore_moved = mover.take
run.log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
run.timer.timestamp!
