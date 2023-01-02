require 'miner_mover'
require 'thread'

t = CompSci::Timer.new
t.timestamp!
t.stamp! "Starting"

stop_mining = false

Signal.trap("INT") {
  t.timestamp!
  t.stamp! " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

CFG = {
  num_miners: 8,
  mining_depth: 4,
  miner_work_type: :cpu,
  random_difficulty: true,
  random_reward: true,

  num_movers: 3,
  batch_size: 5,
  mover_work_type: :cpu,
  random_duration: true,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

# our moving operation executes in its own Ractor
mover = Ractor.new(t) { |t|
  t.stamp! "MOVE Moving operation started"
  q = Thread::Queue.new

  movers = Array.new(CFG[:num_movers]) { |i|
    Thread.new {
      m = MinerMover::Mover.new(CFG[:batch_size],
                                work_type: CFG[:mover_work_type],
                                random_duration: CFG[:random_duration])
      t.stamp! "MOVE #{m.id} Mover #{i} started"
      loop {
        # a mover picks up ore from the queue
        t.stamp! "POP  #{m.id}"
        ore = q.pop
        t.stamp! "POPD #{m.id} #{ore}"

        break if ore == :quit
        m.load_ore ore
        t.stamp! "LOAD #{m}"
        m.log_lines! { |l| t.stamp! l }
      }
      m.move_batch while m.batch > 0
      t.stamp! "QUIT #{m}"
      m
    }
  }

  # Miners feed this Ractor with ore
  # Pass the ore into a queue for the movers
  # When the miners say to quit, tell the movers to quit
  t.stamp! "WAIT Waiting for ore ..."
  loop {
    # when the Ractor gets ore, push it into the queue
    ore = Ractor.recv
    break if ore == :quit
    t.stamp! "RECV #{ore} ore"
    q.push ore
    t.stamp! "PSHD #{ore}"
  }

  # tell all the movers to quit and gather their results
  CFG[:num_movers].times { q.push :quit }
  movers.map { |thr| thr.value.ore_moved }.sum
}

# our mining operation executes in the main Ractor, here
t.stamp! "MINE Mining operation started  [ctrl-c] to stop"
miners = Array.new(CFG[:num_miners]) { |i|
  # spread out miners if uniform difficulty
  sleep 0.5 if !CFG[:random_difficulty] and i > 0

  Thread.new {
    m = MinerMover::Miner.new(work_type: CFG[:miner_work_type],
                              random_difficulty: CFG[:random_difficulty],
                              random_reward: CFG[:random_reward])
    t.stamp! "MINE #{m.id} Miner #{i} started"
    ore_mined = 0

    # miners wait for the SIGINT signal to quit
    while !stop_mining
      ore = m.mine_ore(CFG[:mining_depth])
      # send any ore mined to the mover Ractor
      if ore > 0
        t.stamp! "SEND #{m.id} #{ore}"
        mover.send ore if ore > 0
        t.stamp! "SENT #{m.id} #{ore}"
      end
      ore_mined += ore
      m.log_lines! { |l| t.stamp! l }
    end

    t.stamp! "MINE #{m.id} Miner #{i} stopped after mining #{ore_mined} ore"
    ore_mined
  }
}

# wait on all mining threads to stop
total_ore_mined = miners.map { |thr| thr.value }.sum
t.stamp! "MINE #{total_ore_mined} ore mined"

mover.send :quit
t.stamp! "MOVE #{mover.take} ore moved"
