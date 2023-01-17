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

if ENV['RUBYOPT'].nil? or ENV['RUBYOPT'].empty?
  flags = ["-I #{File.join __dir__, 'lib'}"]
else
  flags = nil # subprocesses will have RUBYOPT
end

# create a rake task to run each script in demo/
Dir['demo/*.rb'].each { |demo_path|
  name = File.basename(demo_path, '.rb')
  desc "Run #{demo_path}"
  args = flags || []
  args << demo_path
  task(name) { ruby *args }
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
