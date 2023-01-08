require 'dotcfg'

module MinerMover
  module Config
    GLOBS = ['*/*.cfg'].freeze

    # reasonable defaults for all known keys
    DEFAULT = {
      main: {
        num_miners: 3,
        num_movers: 3,
        time_limit: 5,
        ore_limit: 100,
        mining_depth: 30,
      }.freeze,
      miner: {
        partial_reward: false,
        variance: 0,
        logging: true,
      }.freeze,
      mover: {
        batch_size: 10,
        rate: 2,
        work_type: :wait,
        variance: 0,
        logging: true,
      }.freeze,
    }.freeze

    # return an array of strings representing file paths
    def self.gather(*globs)
      (GLOBS + globs).inject([]) { |memo, glob| memo + Dir[glob] }
    end

    # return a file path as a string, or nil
    def self.recent(*globs)
      mtime = Time.at 0
      newest = nil
      self.gather(*globs).each { |file|
        mt = File.mtime(file)
        if mt > mtime
          mtime = mt
          newest = file
        end
      }
      newest
    end

    # return a hash with :miner, :mover, :main keys
    def self.process(file = nil)
      file ||= self.recent
      cfg = DotCfg.new(file)

      if cfg['miner'] or cfg['mover']
        # convert string keys to symbols
        miner = (cfg.delete('miner') || {}).transform_keys { |k| k.to_sym }
        mover = (cfg.delete('mover') || {}).transform_keys { |k| k.to_sym }
        main  = (cfg.delete('main')  || {}).transform_keys { |k| k.to_sym }
      elsif cfg[:miner] or cfg[:mover]
        # assume all keys are symbols
        miner = cfg.delete(:miner) || {}
        mover = cfg.delete(:mover) || {}
        main  = cfg.delete(:main)  || {}
      else
        raise "couldn't find miner or mover in #{file}"
      end
      { miner: DEFAULT[:miner].merge(miner),
        mover: DEFAULT[:mover].merge(mover),
        main:  DEFAULT[:main].merge(main) }
    end
  end
end
