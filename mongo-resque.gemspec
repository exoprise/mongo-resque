$LOAD_PATH.unshift 'lib'
require 'resque/version'

Gem::Specification.new do |s|
  s.name        = "mongo-resque"
  s.version     = Resque::Version
  s.authors     = ["David Backeus"]
  s.email       = ["david@streamio.se"]
  s.homepage    = "https://github.com/streamio/mongo-resque"
  s.summary     = "Mongo-Resque is a mongo-backed queueing system"
  s.description = <<-description
    Resque is a Redis-backed Ruby library for creating background jobs,
    placing those jobs on multiple queues, and processing them later.

    Mongo-Resque is the same thing, but for mongo. It would not exist
    without the work of defunkt and ctrochalakis on github.
description

  s.add_dependency "mongo"
  s.add_dependency "vegas",      "~> 0.1.2"
  s.add_dependency "sinatra",    ">= 0.9.2"
  s.add_dependency "multi_json", "~> 1.0"
  
  s.files = Dir["lib/**/*"] + Dir["bin/*"] + Dir["docs/*"] + %w(README.markdown LICENSE HISTORY.md)
  s.executables = %w(resque resque-web)
  s.extra_rdoc_files = %w(LICENSE README.markdown)
end
