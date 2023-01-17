#
# test task
#

require 'rake/testtask'
Rake::TestTask.new :test do |t|
  t.pattern = "test/*.rb"
  t.warning = true
end
task default: :test

#
# demo tasks
#

with_yjit = false # is your ruby even built with YJIT support?
flags = ["-I #{File.join __dir__, 'lib'}"]
flags << '--yjit' if with_yjit

def rubyopt *flags
  format 'RUBYOPT="%s"', flags.join(' ')
end

desc "Show a useful env var"
task(:rubyopt) { puts rubyopt(*flags) }

# create a rake task to run each script in demo/
Dir['demo/*.rb'].each { |demo_path|
  name = File.basename(demo_path, '.rb')
  cmd = format("%s ruby %s", rubyopt(*flags), demo_path)
  desc "Run demo/#{name}#{with_yjit ? ' +YJIT' : ''}"
  task(name) { sh cmd }
}

# jruby / truffleruby lack fiber_scheduler, Ractor, and Process#fork
desc "Run JVM compatible demos"
task jvm_demo: [:serial, :fiber, :thread]

desc "Run all demos"
task demo: [:serial, :fiber, :fiber_scheduler,
            :thread, :ractor, :process_pipe, :process_socket]

#
# release tasks
#

begin
  require 'buildar'

  Buildar.new do |b|
    b.gemspec_file = 'miner_mover.gemspec'
    b.version_file = 'VERSION'
    b.use_git = true
  end
rescue LoadError
  # warn "buildar tasks unavailable"
end
