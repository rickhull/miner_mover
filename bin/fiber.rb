require 'miner_mover'
# require 'fiber'

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
  num_miners: 1,
  mining_depth: 3,
  miner_work_type: :cpu,
  random_difficulty: true,
  random_reward: true,

  num_movers: 1,
  batch_size: 5,
  mover_work_type: :cpu,
  random_duration: true,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts


miner = Fiber.new(blocking: true) {
  m = MinerMover::Miner.new(work_type: CFG[:miner_work_type],
                            random_difficulty: CFG[:random_difficulty],
                            random_reward: CFG[:random_reward])
  t.stamp! "MINE #{m.id} Miner started"
  ore_mined = 0

  # miners wait for the SIGINT signal to quit
  while !stop_mining
    ore = m.mine_ore(CFG[:mining_depth])
    # send any ore mined to the movers
    Fiber.yield ore if ore > 0
    ore_mined += ore
    m.log_lines! { |l| t.stamp! l }
  end

  t.stamp! "MINE #{m.id} Miner stopped after mining #{ore_mined} ore"
  Fiber.yield :quit
  ore_mined
}
t.stamp! "MINE Mining operation started  [ctrl-c] to stop"


mover = MinerMover::Mover.new(CFG[:batch_size],
                              work_type: CFG[:mover_work_type],
                              random_duration: CFG[:random_duration])
t.stamp! "MOVE Moving operation started"
t.stamp! "WAIT Waiting for ore ..."

loop {
  # pick up ore yielded by the miner
  ore = miner.resume
  break if ore == :quit

  # load (and possibly move) the ore
  mover.load_ore ore
  t.stamp! "LOAD #{mover}"
  mover.log_lines! { |l| t.stamp! l }
}

# move any remaining ore and quit
mover.move_batch while mover.batch > 0
mover.log_lines! { |l| t.stamp! l }
t.stamp! "QUIT #{mover}"

t.stamp! "MINE #{miner.resume} ore mined"
t.stamp! "MOVE #{mover.ore_moved} ore moved"
t.timestamp!
