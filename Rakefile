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

desc "run all demos minus fiber_scheduler"
task demo:  [:serial, :fiber, :thread, :ractor, :process]

desc "run all demos"
task demo_all:  [:serial, :fiber, :fiber_scheduler, :thread, :ractor, :process]

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
