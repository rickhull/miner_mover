require 'miner_mover/worker'
require 'miner_mover/config'

module MinerMover
  class Run
    def self.cfg_file(filename = nil)
      f = filename || ARGV.shift || Config.recent
      if f.nil?
        raise(Config::Error, "no config file")
      elsif !File.exist? f
        raise(Config::Error, "can't find file #{f.inspect}")
      elsif !File.readable? f
        raise(Config::Error, "can't read file #{f.inspect}")
      end
      f
    end

    attr_accessor :debug, :logging
    attr_accessor :num_miners, :num_movers
    attr_accessor :cfg_file, :cfg, :miner, :mover, :timer
    attr_accessor :time_limit, :ore_limit

    def initialize(cfg_file: nil, timer: nil, debug: false)
      @cfg_file = self.class.cfg_file(cfg_file)
      @cfg = Config.process @cfg_file
      main  = @cfg.fetch :main
      @miner = @cfg.fetch :miner
      @mover = @cfg.fetch :mover

      @time_limit = main.fetch :time_limit
      @ore_limit  = main.fetch :ore_limit
      @logging    = main.fetch :logging
      @num_miners = main.fetch :num_miners
      @num_movers = main.fetch :num_movers

      @timer = timer || CompSci::Timer.new
      @debug = debug
    end

    def cfg_banner!(sleep_duration = 0)
      log "USING: #{@cfg_file}"
      pp @cfg
      sleep(sleep_duration) if sleep_duration > 0
      self
    end

    def new_miner
      Miner.new(**@miner)
    end

    def new_mover
      Mover.new(**@mover)
    end

    def log msg
      @logging and puts(MinerMover.log_fmt(@timer, ' (main) ', msg))
    end
  end
end
