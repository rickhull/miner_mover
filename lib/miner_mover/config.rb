require 'miner_mover/worker'
require 'dotcfg'

module MinerMover
  module Config
    GLOBS = ['*.config', '*.cfg']

    # minimum key structure; values are irrelevant
    STRUCTURE = {
      main: {
        time_limit: 10,
        ore_limit: 10,
        mining_depth: 30,
      },
      miner: {},
      mover: {},
    }

    # max keys; values are irrelevant
    MAXIMUM = {
      main: {
        num_miners: 2,
        num_movers: 5,
        time_limit: 10,
        ore_limit: 10,
        mining_depth: 30,
      },
      miner: {
        partial_reward: false,
        variance: 0,
        logging: false,
      },
      mover: {
        batch_size: 10,
        rate: 2,
        work_type: :wait,
        variance: 0,
        logging: false,
      },
    }

    DEFAULT = {
      main: {
        num_miners: 2,
        num_movers: 5,
        time_limit: 10,
        ore_limit: 200,
        mining_depth: 30,
      },
      miner: {
        partial_reward: false,
        variance: 0,
        logging: true,
      },
      mover: {
        batch_size: 10,
        rate: 2,
        work_type: :wait,
        variance: 0,
        logging: true,
      },
    }

    def self.gather(*globs)
      (GLOBS + globs).inject([]) { |memo, glob| memo + Dir[glob] }
    end

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

    def self.process(file)
      cfg = DotCfg.new(file)

      # convert string keys to symbols
      if cfg['miner'] or cfg['mover']
        { miner: (cfg.delete('miner') || {}).transform_keys { |k| k.to_sym },
          mover: (cfg.delete('mover') || {}).transform_keys { |k| k.to_sym },
          main: cfg.to_h.transform_keys { |k| k.to_sym },
        }
      elsif cfg[:miner] or cfg[:mover]
        # assume all keys are symbols
        { miner: cfg.delete(:miner),
          mover: cfg.delete(:mover),
          main:  cfg.to_h,
        }
      else
        raise "couldn't find miner or mover in #{file}"
      end
    end

    def self.process_recent(*globs)
      self.check_structure self.process self.recent(*globs)
    end

    def self.check_structure hsh
      STRUCTURE.each { |ks, vs|
        raise "missing key #{ks}: #{hsh.inspect}" unless hsh.key? ks

        if vs.is_a?(Hash)
          vh = hsh[ks]
          raise "hash expected: #{vh.inspect}" unless vh.is_a? Hash
          vs.each { |kks, vvs|
            raise "missing key #{kks}: #{vh.inspect}" unless vh.key? kks
          }
        end
      }
      hsh
    end
  end
end
