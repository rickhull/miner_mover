require 'miner_mover'
require 'thread'

t = MinerMover::Timer.new
t.timestamp!
t.stamp! "Starting"

stop_mining = false

Signal.trap("INT") {
  t.timestamp!
  t.stamp! " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

CFG = {
  num_miners: 5,
  mining_depth: 4,
  miner_work: false,
  random_difficulty: false,
  random_reward: true,

  num_movers: 3,
  batch_size: 4,
  mover_work: false,
  random_duration: true,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

# our moving operation in a separate Ractor
mover = Ractor.new(t) { |t|
  t.stamp! "MOVE Moving operation started"
  q = Thread::Queue.new

  movers = Array.new(CFG[:num_movers]) { |i|
    Thread.new {
      m = MinerMover.new(CFG[:batch_size],
                         perform_work: CFG[:mover_work],
                         random_duration: CFG[:random_duration])
      t.stamp! "MOVE Mover #{i} started (#{m.object_id})"
      loop {
        ore = q.pop
        break if ore == :quit
        m.load_ore ore
        t.stamp! "LOAD #{m}"
      }
      m.move_batch while m.batch > 0
      t.stamp! "QUIT #{m}"
      m
    }
  }

  # main thread feeds the queue with ore
  # and tells the workers when to quit
  t.stamp! "WAIT Waiting for ore ..."
  loop {
    ore = Ractor.recv
    break if ore == :quit
    t.stamp! "RECV #{ore} ore"
    q.push ore
  }
  CFG[:num_movers].times { q.push :quit }
  movers.map { |thr| thr.value.ore_moved }.sum
}

# Here we go!
t.stamp! "MINE Mining operation started  [ctrl-c] to stop"
miners = Array.new(CFG[:num_miners]) { |i|
  # spread out miners if uniform difficulty
  sleep 0.5 if !CFG[:random_difficulty] and i > 0
  Thread.new {
    t.stamp! "MINE Miner #{i} started"
    ore_mined = 0
    while !stop_mining
      ore = MinerMover.mine_ore(CFG[:mining_depth],
                                perform_work: CFG[:miner_work],
                                random_difficulty: CFG[:random_difficulty],
                                random_reward: CFG[:random_reward])
      mover.send ore if ore > 0
      ore_mined += ore
      break if stop_mining
    end
    t.stamp! "MINE Miner #{i} stopped after mining #{ore_mined} ore"
    ore_mined
  }
}

# wait on all mining threads to stop
total_ore_mined = miners.map { |thr| thr.value }.sum
t.stamp! "MINE #{total_ore_mined} ore mined"

mover.send :quit
t.stamp! "MOVE #{mover.take} ore moved"
