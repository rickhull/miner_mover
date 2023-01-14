require 'miner_mover/run'
require 'thread'

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

pipe_reader, pipe_writer = IO.pipe

def pipe_reader.pop
  Ore.decode self.read(Ore::WORD_LENGTH)
end

def pipe_writer.push amt
  self.write(Ore.encode(amt))
end

# the moving operation executes in its own Process
mover = Process.fork {
  run.log "MOVE Moving operation started"

  # pipes only want one end open; we're reading here
  pipe_writer.close

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
    ore = pipe_reader.pop
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

# pipes only want one end open; we're writing here
pipe_reader.close

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
      pipe_writer.push(ore) if ore > 0

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
pipe_writer.push 0

# wait for results
Process.wait
run.timestamp!
