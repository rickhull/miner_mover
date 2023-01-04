require 'miner_mover'
require 'thread'

CFG = {
  time_limit: 20, # seconds
  ore_limit: 100, # million

  num_miners: 1,
  mining_depth: 30,
  random_difficulty: false,
  guarantee: true,

  num_movers: 5,
  batch_size: 10, # million
  mover_work: :cpu,
  random_duration: false,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

TIMER = CompSci::Timer.new.freeze
DEBUG = false

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

# our moving operation executes in its own Ractor
mover = Ractor.new {
  log "MOVE Moving operation started"

  # use queue to distribute incoming ore to mover threads
  q = Thread::Queue.new

  movers = Array.new(CFG[:num_movers]) { |i|
    Thread.new {
      m = Mover.new(CFG[:batch_size],
                    timer: TIMER,
                    logging: true,
                    work_type: CFG[:mover_work],
                    random_duration: CFG[:random_duration])

      m.log "MOVE Mover #{i} started"
      loop {
        # a mover picks up ore from the queue
        DEBUG && m.log("POP ")
        ore = q.pop
        DEBUG && m.log("POPD #{ore}")

        break if ore == :quit

        # load (and possibly move) the ore
        m.load_ore ore
      }

      # move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m}"
      m
    }
  }

  # Miners feed this Ractor with ore
  # Pass the ore into a queue for the movers
  # When the miners say to quit, tell the movers to quit
  log "WAIT Waiting for ore ..."
  loop {
    # when the Ractor gets ore, push it into the queue
    ore = Ractor.recv
    DEBUG && log("RECV #{ore}")

    break if ore == :quit

    DEBUG && log("PUSH #{ore}")
    q.push ore
    DEBUG && log("PSHD #{ore}")
  }

  # tell all the movers to quit and gather their results
  CFG[:num_movers].times { q.push :quit }
  movers.map { |thr| thr.value.ore_moved }.sum
}

# our mining operation executes in the main Ractor, here
log "MINE Mining operation started  [ctrl-c] to stop"
miners = Array.new(CFG[:num_miners]) { |i|
  # spread out miners if uniform difficulty
  sleep 0.5 if !CFG[:random_difficulty] and i > 0

  Thread.new {
    m = Miner.new(timer: TIMER,
                  logging: true,
                  random_difficulty: CFG[:random_difficulty],
                  guarantee: CFG[:guarantee])
    m.log "MINE Miner #{i} started"
    ore_mined = 0

    # miners wait for the SIGINT signal to quit
    while !stop_mining
      ore = m.mine_ore(CFG[:mining_depth])

      # send any ore mined to the mover Ractor
      if ore > 0
        DEBUG && m.log("SEND #{ore}")
        mover.send ore
        DEBUG && m.log("SENT #{ore}")
      end

      ore_mined += ore

      # stop mining after a while
      if TIMER.elapsed > CFG[:time_limit] or
        Ore.block(ore_mined) > CFG[:ore_limit]
        TIMER.timestamp!
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
log format("MINE %s mined (%i)", Ore.display(ore_mined), ore_mined)

# tell mover to quit
mover.send :quit

# wait for results
ore_moved = mover.take
log format("MOVE %s moved (%i)", Ore.display(ore_moved), ore_moved)
TIMER.timestamp!
