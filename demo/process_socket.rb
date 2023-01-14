require 'miner_mover/run'
require 'thread'
require 'socket'

include MinerMover

run = Run.new.cfg_banner!(duration: 1).start!
run.debug = true
run.timestamp!
run.log "Starting"

stop_mining = false
Signal.trap("INT") {
  run.timestamp!
  run.log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

csock, psock = Socket.pair(:UNIX, :DGRAM, 0)

def csock.pop
  Ore.decode self.recv(Ore::WORD_LENGTH)
end

def psock.push amt
  self.send(Ore.encode(amt), 0)
end

# the moving operation executes in its own Process
mover = Process.fork {
  run.log "MOVE Moving operation started"

  # close the parent socket, here in the child process
  psock.close

  # create a queue to feed multiple movers
  queue = Thread::Queue.new

  # store the mover threads in an array
  movers = Array.new(run.num_movers) { |i|
    Thread.new {
      m = run.new_mover
      m.log "MOVE Mover #{i} started"

      loop {
        # a mover picks up ore from the queue
        ore = queue.pop

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

  # Miners feed this Process with ore
  # Pass the ore into a queue for the movers
  # When the miners say to quit, tell the movers to quit
  run.log "WAIT Waiting for ore ..."
  loop {
    ore = csock.pop
    break if ore == 0 # signal to quit
    queue.push ore
  }

  # tell all the movers to quit and gather their results
  run.num_movers.times { queue.push :quit }
  ore_moved = movers.map { |thr| thr.value.ore_moved }.sum
  run.log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
}

# our mining operation executes in the main process, here
run.log "MINE Mining operation started  [ctrl-c] to stop"

# close the child socket, here in the parent
csock.close

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

      # send any ore mined down the pipe to the movers
      psock.push(ore) if ore > 0

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

# tell mover to quit
psock.push 0

# wait for results
Process.wait
run.timestamp!
