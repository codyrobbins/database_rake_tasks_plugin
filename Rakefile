require('rake')
require('rake/testtask')

desc('Default: Run unit tests.')
task(:default => :test)

desc('Test the rake_tasks plugin.')
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end