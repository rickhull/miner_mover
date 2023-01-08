require 'miner_mover/config'

cfg_file = ARGV.shift || MinerMover::Config.recent
cfg_file ? puts("USING: #{cfg_file}") :  raise("no config file available")

pp MinerMover::Config.process(cfg_file)
