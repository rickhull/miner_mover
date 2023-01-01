require 'miner_mover'
require 'thread'

stop_mining = false

Signal.trap("INT") {
  puts "trapped SIGINT: stop mining"
  stop_mining = true
}

NUM_MOVERS = 3
BATCH_SIZE = 5

NUM_MINERS = 5
MINING_DEPTH = 4

mover = Ractor.new {
  movers = []
  q = Thread::Queue.new

  NUM_MOVERS.times { |i|
    movers << Thread.new {

####### MOVER LOOP #######
      m = MinerMover.new(BATCH_SIZE)
      loop {
        ore = q.pop
        break if ore == :quit
        m.load_ore ore
        p m
      }
      m.move_batch while m.batch > 0
      puts "QUIT: #{m.inspect}"
##########################

    }
  }

  # main thread feeds the queue with ore
  # and tells the workers when to quit

  loop {
    ore = Ractor.recv
    break if ore == :quit
    puts "Received #{ore} ore"
    q.push ore
  }
  NUM_MOVERS.times { q.push :quit }

  movers.each(&:join)
  "Movers done"
}

miners = []

NUM_MINERS.times { |i|
  miners << Thread.new {

##### MINER LOOP #######
    loop {
      ore = MinerMover.mine_ore(MINING_DEPTH)
      mover.send ore if ore > 0
      break if stop_mining
    }
########################

  }
}

miners.each(&:join)
puts "Miners are stopped"

mover.send :quit
puts "Told the Mover to quit"

puts "Mover: #{mover.take}"
