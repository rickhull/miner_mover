require 'miner_mover'

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
  num_miners: 1,   # unused
  mining_depth: 3,
  miner_work_type: :wait,
  random_difficulty: true,
  random_reward: true,

  num_movers: 1,   # unused
  batch_size: 5,
  mover_work_type: :wait,
  random_duration: true,
}.freeze

puts
puts CFG.to_a.map { |(k, v)| format("%s: %s", k, v) }
puts

miner = MinerMover::Miner.new(work_type: CFG[:miner_work_type],
                              random_difficulty: CFG[:random_difficulty],
                              random_reward: CFG[:random_reward])
t.stamp! "MINE Mining operation started  [ctrl-c] to stop"
ore_mined = 0

mover = MinerMover::Mover.new(CFG[:batch_size],
                              work_type: CFG[:mover_work_type],
                              random_duration: CFG[:random_duration])
t.stamp! "MOVE Moving operation started"
t.stamp! "WAIT Waiting for ore ..."

# miner waits for the SIGINT signal to quit
while !stop_mining
  # miner stuff
  ore = miner.mine_ore(CFG[:mining_depth])
  ore_mined += ore
  miner.log_lines! { |l| t.stamp! l }

  # mover stuff
  mover.load_ore ore if ore > 0
  t.stamp! "LOAD #{mover}"
  mover.log_lines! { |l| t.stamp! l }
end

# miner has quit
mover.move_batch while mover.batch > 0
mover.log_lines! { |l| t.stamp! l }
t.stamp! "QUIT #{mover}"

t.stamp! "MINE #{ore_mined} ore mined"
t.stamp! "MOVE #{mover.ore_moved} ore moved"
t.timestamp!
