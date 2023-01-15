require 'dotcfg'

module MinerMover
  module Config
    class Error < RuntimeError; end

    GLOB = '*/*.cfg'.freeze

    # reasonable defaults for all known keys
    DEFAULT = {
      main: {
        num_miners: 3,
        num_movers: 3,
        time_limit: 5,
        ore_limit: 100,
        logging: true,
        debugging: false,
      }.freeze,
      miner: {
        depth: 30,
        partial_reward: false,
        variance: 0,
        logging: true,
        debugging: false,
      }.freeze,
      mover: {
        batch_size: 8,
        rate: 4,
        work_type: :wait,
        variance: 0,
        logging: true,
        debugging: false,
      }.freeze,
    }.freeze

    # return an array of strings representing file paths
    def self.gather(*globs)
      (globs.unshift GLOB).inject([]) { |memo, glob| memo + Dir[glob] }
    end

    # return a file path as a string, or nil
    def self.recent(*globs)
      mtime, newest = Time.at(0), nil
      self.gather(*globs).each { |file|
        mt = File.mtime(file)
        mtime, newest = mt, file if mt > mtime
      }
      newest
    end

    # return a hash with :miner, :mover, :main keys
    def self.process(file = nil, cfg: nil)
      cfg ||= DotCfg.new(file || self.recent)

      if cfg['miner'] or cfg['mover'] or cfg['main']
        # convert string keys to symbols
        miner = (cfg['miner'] || {}).transform_keys { |k| k.to_sym }
        mover = (cfg['mover'] || {}).transform_keys { |k| k.to_sym }
        main  = (cfg['main']  || {}).transform_keys { |k| k.to_sym }
      elsif cfg[:miner] or cfg[:mover] or cfg[:main]
        # assume all keys are symbols
        miner = cfg[:miner] || {}
        mover = cfg[:mover] || {}
        main  = cfg[:main]  || {}
      else
        miner, mover, main = {}, {}, {}
      end
      { miner: DEFAULT[:miner].merge(miner),
        mover: DEFAULT[:mover].merge(mover),
        main:  DEFAULT[:main].merge(main) }
    end

    # rewrites the dotcfg file, filling in any defaults, using symbols for keys
    def self.rewrite(file)
      cfg = DotCfg.new(file)
      hsh = self.process(cfg: cfg)
      hsh.each { |k, v| cfg[k] = v }
      cfg.save
    end
  end
end
