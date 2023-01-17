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

with_yjit = false   # very unlikely that your ruby has YJIT support
# create a rake task to run each script in demo/
Dir['demo/*.rb'].each { |demo_path|
  name = File.basename(demo_path, '.rb')
  enable_yjit = with_yjit ? '--enable-yjit' : ''
  desc "Run demo/#{name}#{with_yjit ? ' +YJIT' : ''}"
  task(name) { sh "ruby -Ilib #{enable_yjit} #{demo_path}" }
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
