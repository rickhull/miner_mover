require 'miner_mover'
require 'thread'

stop_mining = false

Signal.trap("INT") {
  puts " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

CFG = {
  num_miners: 5,
  mining_depth: 4,
  miner_work: true,

  num_movers: 3,
  batch_size: 5,
  mover_work: false,
}.freeze

p CFG

# our moving operation in a separate Ractor
mover = Ractor.new {
  puts "Starting the moving operation ..."
  q = Thread::Queue.new

  movers = Array.new(CFG[:num_movers]) { |i|
    Thread.new {
      puts "Mover #{i} started ..."
      m = MinerMover.new(CFG[:batch_size], perform_work: CFG[:mover_work])
      loop {
        ore = q.pop
        break if ore == :quit
        m.load_ore ore
        p m
      }
      m.move_batch while m.batch > 0
      puts "QUIT: #{m.inspect}"
    }
  }

  # main thread feeds the queue with ore
  # and tells the workers when to quit
  puts "Waiting for ore ..."
  loop {
    ore = Ractor.recv
    break if ore == :quit
    puts "Received #{ore} ore"
    q.push ore
  }
  CFG[:num_movers].times { q.push :quit }

  movers.each(&:join)
  "Movers done"
}


# Here we go!
puts "Mining started ... \t[ctrl-c] to stop"

miners = Array.new(CFG[:num_miners]) { |i|
  Thread.new {
    puts "Miner #{i} started ..."
    while !stop_mining
      ore = MinerMover.mine_ore(CFG[:mining_depth], perform_work: CFG[:miner_work])
      mover.send ore if ore > 0
      break if stop_mining
    end
  }
}

miners.each(&:join)
puts "Miners are stopped; telling the mover to quit"

mover.send :quit
puts "Mover: #{mover.take}"
