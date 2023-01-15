require 'miner_mover/run'
require 'fiber_scheduler'

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

# for moving ore
queue = Thread::Queue.new

# for signalling between miners and supervisor
mutex = Mutex.new
miner_quit = ConditionVariable.new

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

      while !stop_mining # SIGINT will trigger stop_mining = true
        ore = m.mine_ore
        ore_mined += ore
        queue.push(ore) if ore > 0

        # stop mining after a while
        if run.time_limit? or run.ore_limit?(ore_mined)
          run.timestamp!
          m.log format("Mining limit reached: %s", Ore.display(ore_mined))
          stop_mining = true
        end
      end

      m.log format("MINE Miner #{i} finished after mining %s",
                   Ore.display(ore_mined))

      # register the ore mined (scheduled fiber can't return a value)
      mined.push ore_mined

      # signal to the supervisor that a miner is done
      mutex.synchronize { miner_quit.signal }
    end
  }

  # several movers, no need to store
  run.num_movers.times { |i|

    # each mover gets a fiber
    Fiber.schedule do
      m = run.new_mover
      m.log "MOVE Mover #{i} started"

      # movers pull from the queue, load the ore, and move it
      loop {
        ore = queue.pop
        break if ore == :quit
        m.load_ore ore if ore > 0 # move_batch happens when a batch is full
      }

      # move any remaining ore and quit
      m.move_batch while m.batch > 0
      m.log "QUIT #{m.status}"

      # register the ore moved (scheduled fiber can't return a value)
      moved.push m.ore_moved
    end
  }

  # supervisor waits for the miners to quit
  # and signals the mover to quit by pushing :quit onto the queue
  Fiber.schedule do
    # every time a miner quits, check if any are left
    mutex.synchronize { miner_quit.wait(mutex) while miners.any?(&:alive?) }

    # tell every mover to quit
    run.num_movers.times { queue.push(:quit) }

    # queue only closes once it is empty
    queue.close # should helpfully cause errors if something is out of sync
  end
end

total_mined = 0
total_mined += mined.pop until mined.empty?

total_moved = 0
total_moved += moved.pop until moved.empty?

run.log format("MINE %s mined (%i)", Ore.display(total_mined), total_mined)
run.log format("MOVE %s moved (%i)", Ore.display(total_moved), total_moved)
run.timestamp!
