require 'dotcfg'

module MinerMover
  module Config
    GLOBS = ['*/*.cfg']

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

    # reasonable defaults for all known keys
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
    def self.process(file)
      cfg = DotCfg.new(file)

      # convert string keys to symbols
      if cfg['miner'] or cfg['mover']
        { miner: (cfg.delete('miner') || {}).transform_keys { |k| k.to_sym },
          mover: (cfg.delete('mover') || {}).transform_keys { |k| k.to_sym },
          main:  (cfg.delete('main')  || {}).transform_keys { |k| k.to_sym },
        }
      elsif cfg[:miner] or cfg[:mover]
        # assume all keys are symbols
        { miner: cfg.delete(:miner),
          mover: cfg.delete(:mover),
          main:  cfg.delete(:main),
        }
      else
        raise "couldn't find miner or mover in #{file}"
      end
    end

    # return a hash that has been structurally checked, or nil
    def self.process_recent(*globs)
      file = self.recent(*globs) or return nil
      self.check_structure self.process file
    end

    # check for required keys; raise on failure
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
