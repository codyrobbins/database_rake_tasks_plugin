#  -*- eval: (remove-hook 'write-file-functions 'delete-trailing-whitespace); -*-

# The YAML output by db:fixtures:export has trailing whitespace, so to
# test it below the above is necessary to disable my Emacs hook that
# removes trailing whitespace on save.

require('test_helper')
require('sakuzaku/database_rake_tasks')
require('rake')
require('active_record')

class DatabaseRakeTasksTest < ActiveSupport::TestCase
  def setup
    set_constant(:RAILS_ENV, 'test')
    set_constant(:RAILS_ROOT, '/rails')
  end

  test('exports fixtures') do
    fixture_directory = '/rails/test/fixtures/test'

    File.stubs(:exists? => false)
    Dir.expects(:mkdir).with(fixture_directory)

    assert_system_call("rm -f '#{fixture_directory}#{File::SEPARATOR}'*.yml")

    connection = mock
    connection.stubs(:tables => ['foo', 'schema_info', 'schema_migrations', 'zzz'])
    connection.expects(:select_all).with('SELECT * FROM foo').returns([{'id' => 1, 'name' => 'foo1'}, {'id' => 2, 'name' => 'foo2'}])
    connection.expects(:select_all).with('SELECT * FROM zzz').returns([{'foo' => 'bar', 'quux' => 'quuxy'}, {'foo' => 'zzz', 'quux' => 'quuuxy'}, {'foo' => 'test', 'quux' => 'quuuuxy'}])

    ActiveRecord::Base.stubs(:establish_connection)
    ActiveRecord::Base.stubs(:connection => connection)

    file_mock = mock
    file_mock.expects(:write).with(<<YAML
--- 
foo_1: 
  name: foo1
  id: 1
foo_2: 
  name: foo2
  id: 2
YAML
)

    File.expects(:open).with(File.join(fixture_directory, 'foo.yml'), 'w').yields(file_mock)

    file_mock = mock
    file_mock.expects(:write).with(<<YAML
--- 
zzz_1: 
  quux: quuxy
  foo: bar
zzz_2: 
  quux: quuuxy
  foo: zzz
zzz_3: 
  quux: quuuuxy
  foo: test
YAML
)

    File.expects(:open).with(File.join(fixture_directory, 'zzz.yml'), 'w').yields(file_mock)

    suppress_puts
    Sakuzaku::DatabaseRakeTasks.export_fixtures
  end

  test('purges') do
    connection = mock
    connection.stubs(:tables => ['foo', 'schema_info', 'schema_migrations', 'zzz'])
    connection.expects(:delete).with('DELETE FROM foo')
    connection.expects(:delete).with('DELETE FROM zzz')

    ActiveRecord::Base.stubs(:connection => connection)

    Sakuzaku::DatabaseRakeTasks.purge
  end

  test('recreates') do
    assert_rake_tasks_invoked(:drop, :create)
    Sakuzaku::DatabaseRakeTasks.recreate
  end

  test('recreates all') do
    assert_all_databases_execute(:recreate)
    Sakuzaku::DatabaseRakeTasks.recreate_all
  end

  test('migrates all') do
    assert_all_databases_execute(:migrate)
    Sakuzaku::DatabaseRakeTasks.migrate_all
  end

  test('resets all') do
    assert_all_databases_execute('migrate:reset')
    Sakuzaku::DatabaseRakeTasks.reset_all
  end

  test('verifies') do
    assert_rake_tasks_invoked('migrate:reset')

    system_call = Sakuzaku::DatabaseRakeTasks.expects(:`)
    system_call.with("git status --porcelain '/rails/db/migrate' | awk '{if ($1 == \"??\" || $1 == \"A\") print $2}'")
    system_call.returns(<<TEXT
db/migrate/20100716061416_foo.rb
db/migrate/20100716061424_bar.rb
db/migrate/20100716061458_quux.rb
TEXT
)

    ['20100716061416_foo',
     '20100716061424_bar',
     '20100716061458_quux'].each do |version|
      assert_rake_invoked_via_system("migrate:down VERSION=#{version}")
    end

    assert_rake_invoked_via_system('migrate')

    Sakuzaku::DatabaseRakeTasks.verify
  end

  protected

  def set_constant(name, value)
    unless Sakuzaku::DatabaseRakeTasks.const_defined?(name)
      Sakuzaku::DatabaseRakeTasks.send(:const_set, name, value)
    end
  end

  def assert_rake_tasks_invoked(*tasks)
    tasks.each do |task|
      task_mock = mock
      task_mock.expects(:invoke)

      Rake::Task.expects(:[]).with("db:#{task}").returns(task_mock)
    end
  end

  def assert_all_databases_execute(task)
    suppress_puts
    configurations = [:development, :test, :production]

    ActiveRecord::Base.stubs(:configurations => configurations)

    configurations.each do |configuration|
      assert_rake_invoked_via_system("#{task} RAILS_ENV=#{configuration}")
    end
  end

  def assert_rake_invoked_via_system(command)
    assert_system_call("rake db:#{command}")
  end

  def assert_system_call(command)
    Sakuzaku::DatabaseRakeTasks.expects(:system).with(command)
  end

  def suppress_puts
    Sakuzaku::DatabaseRakeTasks.stubs(:puts)
  end
end
