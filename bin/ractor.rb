require 'miner_mover'
require 'thread'

stop_mining = false

Signal.trap("INT") {
  puts " *** SIGINT ***  Stop Mining"
  stop_mining = true
}

NUM_MOVERS = 3
BATCH_SIZE = 5

NUM_MINERS = 5
MINING_DEPTH = 4

puts "NUM_MINERS = #{NUM_MINERS}"
puts "MINING_DEPTH = #{MINING_DEPTH}"
puts "NUM_MOVERS = #{NUM_MOVERS}"
puts "BATCH_SIZE = #{BATCH_SIZE}"
puts

# our moving operation in a separate Ractor
mover = Ractor.new {
  puts "Starting the moving operation ..."
  movers = []
  q = Thread::Queue.new

  NUM_MOVERS.times { |i|
    movers << Thread.new {
      #### MOVER LOOP ####
      puts "Mover #{i} started ..."
      m = MinerMover.new(BATCH_SIZE)
      loop {
        ore = q.pop
        break if ore == :quit
        m.load_ore ore
        p m
      }
      m.move_batch while m.batch > 0
      puts "QUIT: #{m.inspect}"
      ####################

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
  NUM_MOVERS.times { q.push :quit }

  movers.each(&:join)
  "Movers done"
}


# Here we go!
puts "Mining started ... \t[ctrl-c] to stop"

miners = []

NUM_MINERS.times { |i|
  miners << Thread.new {

    ##### MINER LOOP ######
    puts "Miner #{i} started ..."
    loop {
      ore = MinerMover.mine_ore(MINING_DEPTH)
      mover.send ore if ore > 0
      break if stop_mining
    }
    #######################

  }
}

miners.each(&:join)
puts "Miners are stopped; telling the mover to quit"

mover.send :quit
puts "Mover: #{mover.take}"
