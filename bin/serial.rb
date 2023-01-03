require 'miner_mover'

MAIN_ID = ' (main) '

t = CompSci::Timer.new
t.timestamp!
MinerMover.log!(t, MAIN_ID, "Starting")

stop_mining = false

Signal.trap("INT") {
  t.timestamp!
  MinerMover.log!(t, MAIN_ID, " *** SIGINT ***  Stop Mining")
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
                              timer: t,
                              random_difficulty: CFG[:random_difficulty],
                              random_reward: CFG[:random_reward])
MinerMover.log! t, MAIN_ID, "MINE Mining operation started  [ctrl-c] to stop"

mover = MinerMover::Mover.new(CFG[:batch_size],
                              timer: t,
                              work_type: CFG[:mover_work_type],
                              random_duration: CFG[:random_duration])
MinerMover.log! t, MAIN_ID, "MOVE Moving operation started"
MinerMover.log! t, MAIN_ID, "WAIT Waiting for ore ..."

ore_mined = 0

# miner waits for the SIGINT signal to quit
while !stop_mining
  # miner stuff
  ore = miner.mine_ore(CFG[:mining_depth])
  ore_mined += ore

  # mover stuff
  mover.load_ore ore if ore > 0
end

# miner has quit
mover.move_batch while mover.batch > 0
MinerMover.log! t, MAIN_ID, "QUIT #{mover}"

MinerMover.log! t, MAIN_ID, "MINE #{ore_mined} ore mined"
MinerMover.log! t, MAIN_ID, "MOVE #{mover.ore_moved} ore moved"
t.timestamp!
