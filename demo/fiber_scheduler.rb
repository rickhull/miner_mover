require 'miner_mover/run'
require 'fiber_scheduler'

include MinerMover

run = Run.new
puts "USING: #{run.cfg_file}"
pp run.cfg
sleep 1

run.timer.timestamp!
run.log "Starting"

stop_mining = false
Signal.trap("INT") {
  run.timer.timestamp!
  run.log " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

# for moving ore
queue = Thread::Queue.new

# for signalling between miners and supervisor
mutex = Mutex.new
cond = ConditionVariable.new

# for getting results from scheduled fibers
mined = Thread::Queue.new
moved = Thread::Queue.new

# follow the rabbit
FiberScheduler do

  # several miners, stored in an array
  miners = Array.new(run.num_miners) { |i|

    # each miner gets a fiber
    Fiber.schedule do
      m = run.new_miner
      m.log "MINE Miner #{i} started"

      ore_mined = 0

      # miner waits for the SIGINT signal to quit
      while !stop_mining
        ore = m.mine_ore

        # send any ore mined to the mover
        queue.push(ore) if ore > 0
        ore_mined += ore

        # stop mining after a while
        if run.timer.elapsed > run.time_limit or
          Ore.block(ore_mined) > run.ore_limit
          run.timer.timestamp!
          m.log format("Mining limit reached: %s", Ore.display(ore_mined))
          stop_mining = true
        end
      end

      m.log format("MINE Miner #{i} finished after mining %s",
                   Ore.display(ore_mined))

      # accumulate ore mined (nonblocking fiber can't return a value)
      mined.push ore_mined
      mutex.synchronize { cond.signal }
    end
  }

  # several movers, no need to store
  run.num_movers.times { |i|

    # each mover gets a fiber
    Fiber.schedule do
      m = run.new_mover
      m.log "MOVE Mover #{i} started"

      loop {
        # pick up ore from the miner until we get a :quit message
        ore = queue.pop
        break if ore == :quit

        # load (and possibly move) the ore
        m.load_ore ore if ore > 0
      }

      # miners have quit; move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m.status}"

      # register the ore moved (scheduled fiber can't return a value)
      moved.push m.ore_moved
    end
  }

  # supervisor waits for the miners to quit and signals the movers
  # to quit by pushing :quit into the queue
  Fiber.schedule do
    mutex.synchronize { cond.wait(mutex) while miners.any?(&:alive?) }
    run.num_movers.times { queue.push(:quit) }
    queue.close # should helpfully cause errors if anything is out of sync
  end
end

total_mined = 0
total_mined += mined.pop until mined.empty?

total_moved = 0
total_moved += moved.pop until moved.empty?

run.log format("MINE %s mined (%i)", Ore.display(total_mined), total_mined)
run.log format("MOVE %s moved (%i)", Ore.display(total_moved), total_moved)
run.timer.timestamp!
