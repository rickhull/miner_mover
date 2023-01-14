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
  pipe_writer.close # we're only using pipe_reader in this process
  queue = Thread::Queue.new # distribute incoming ore to mover threads

  # store the mover threads in an array
  movers = Array.new(run.num_movers) { |i|
    Thread.new {
      m = run.new_mover
      m.log "MOVE Mover #{i} started"

      # movers pull from the queue, load the ore, and move it
      loop {
        ore = queue.pop
        break if ore == :quit
        m.load_ore ore # move_batch happens when a batch is full
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
pipe_reader.close # we're only using pipe_writer in this process

# store the miner threads in an array
miners = Array.new(run.num_miners) { |i|
  Thread.new {
    m = run.new_miner
    m.log "MINE Miner #{i} started"
    ore_mined = 0

    while !stop_mining # SIGINT will trigger stop_mining = true
      ore = m.mine_ore
      ore_mined += ore
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
