Gem::Specification.new do |s|
  s.name = 'miner_mover'
  s.summary = "This project provides a basic concurrency problem useful for" <<
              " exploring different multitasking paradigms available in Ruby"
  s.description = <<EOF
Fundamentally, we have a set of miners and a set of movers. A miner takes some amount of time to mine ore, which is given to a mover. When a mover has enough ore for a full batch, the delivery takes some amount of time before more ore can be loaded.
EOF
    s.authors = ["Rick Hull"]
  s.homepage = "https://github.com/rickhull/miner_mover"
  s.license = "LGPL-3.0"

  s.required_ruby_version = "~> 2"

  s.version = File.read(File.join(__dir__, 'VERSION')).chomp

  s.files = %w[miner_mover.gemspec VERSION README.md Rakefile]
  s.files += Dir['lib/**/*.rb']
  s.files += Dir['test/**/*.rb']
  s.files += Dir['demo/**/*.rb']

  s.add_dependency "dotcfg", "~> 1.0"

  s.requirements << "For all features and best performance:"
  s.requirements << "gem install rake minitest fiber_scheduler"
  s.requirements << "For dev tools:"
  s.requirements << "gem install buildar flog flay"

  s.add_development_dependency "rake", "~> 13.0" # CVE-2020-8130
  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "buildar", "~> 3.0"
  s.add_development_dependency "flog", "~> 0"
  s.add_development_dependency "flay", "~> 0"
end
