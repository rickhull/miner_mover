require 'rake/testtask'

Rake::TestTask.new :test do |t|
  t.pattern = "test/*.rb"
  t.warning = true
end

desc "rake test"
task default: :test

Dir['demo/*.rb'].each { |demo_path|
  name = File.basename(demo_path, '.rb')
  desc "run demo/#{name}"
  task(name) { sh "ruby -Ilib #{demo_path}" }
}

# jruby / truffleruby lack fiber_scheduler, Ractor, and Process#fork
desc "run all demos minus fiber_scheduler / ractor / process"
task alt_demo: [:serial, :fiber, :thread]

desc "run all demos"
task demo: [:serial, :fiber, :fiber_scheduler, :thread, :ractor, :process_pipe]

begin
  require 'buildar'

    Buildar.new do |b|
    b.gemspec_file = 'miner_mover.gemspec'
    b.version_file = 'VERSION'
    b.use_git = true
  end
rescue LoadError
  warn "buildar tasks unavailable"
end
