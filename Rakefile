#
# Setup
#

load 'lib/tasks/resque.rake'

$LOAD_PATH.unshift 'lib'
require 'resque/tasks'

def command?(command)
  system("type #{command} > /dev/null 2>&1")
end


#
# Tests
#

require 'rake/testtask'

task :default => :test


if command?(:rg)
  desc "Run the test suite with rg"
  task :test do
    Dir['test/**/*_test.rb'].each do |f|
      sh("rg #{f}")
    end
  end
else
  Rake::TestTask.new do |test|
    test.libs << "test"
    test.test_files = FileList['test/**/*_test.rb']
  end
end

if command? :kicker
  desc "Launch Kicker (like autotest)"
  task :kicker do
    puts "Kicking... (ctrl+c to cancel)"
    exec "kicker -e rake test lib examples"
  end
end


#
# Install
#

task :install => [ 'dtach:install' ]


#
# Documentation
#

begin
  require 'sdoc_helpers'
rescue LoadError
end


#
# Publishing
#

desc "Push a new version to Rubygems"
task :publish do
  require 'resque/version'

  sh "gem build mongo-resque.gemspec"
  sh "gem push mongo-resque-#{Resque::Version}.gem"
  sh "git tag mongo-v#{Resque::Version}"
  sh "git push origin mongo-v#{Resque::Version}"
  sh "git push origin master"
  sh "rm mongo-resque*.gem"
end
