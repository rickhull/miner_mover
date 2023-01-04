require 'miner_mover'
require 'thread'

CFG = {
  num_miners: 4,
  mining_depth: 25,
  random_difficulty: true,
  random_reward: true,

  num_movers: 3,
  batch_size: 10,
  mover_work: :cpu,
  random_duration: true,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

TIMER = CompSci::Timer.new.freeze

def log(msg)
  puts MinerMover.log(TIMER, ' (main) ', msg)
end

TIMER.timestamp!
log "Starting"

stop_mining = false

Signal.trap("INT") {
  TIMER.timestamp!
  log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

# our moving operation executes in its own Ractor
mover = Ractor.new {
  log "MOVE Moving operation started"

  # use queue to distribute incoming ore to mover threads
  q = Thread::Queue.new

  movers = Array.new(CFG[:num_movers]) { |i|
    Thread.new {
      m = MinerMover::Mover.new(CFG[:batch_size],
                                timer: TIMER,
                                logging: true,
                                work_type: CFG[:mover_work],
                                random_duration: CFG[:random_duration])
      m.log "MOVE Mover #{i} started"
      loop {
        # a mover picks up ore from the queue
        m.log "POP "
        ore = q.pop
        m.log "POPD #{ore}"

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
    log "RECV #{ore}"

    break if ore == :quit

    log "PSH  #{ore}"
    q.push ore
    log "PSHD #{ore}"
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
    m = MinerMover::Miner.new(timer: TIMER,
                              logging: true,
                              random_difficulty: CFG[:random_difficulty],
                              random_reward: CFG[:random_reward])
    m.log "MINE Miner #{i} started"
    ore_mined = 0

    # miners wait for the SIGINT signal to quit
    while !stop_mining
      ore = m.mine_ore(CFG[:mining_depth])

      # send any ore mined to the mover Ractor
      if ore > 0
        m.log "SEND #{ore}"
        mover.send ore
        m.log "SENT #{ore}"
      end

      ore_mined += ore
    end

    m.log "MINE Miner #{i} finished after mining #{ore_mined} ore"
    ore_mined
  }
}

# wait on all mining threads to stop
ore_mined = miners.map { |thr| thr.value }.sum
log format("MINE %.2fM ore mined (%i)", ore_mined.to_f / 1_000_000, ore_mined)

# tell mover to quit
mover.send :quit

# wait for results
ore_moved = mover.take
log format("MOVE %.2fM ore moved (%i)", ore_moved.to_f / 1_000_000, ore_moved)
TIMER.timestamp!
