module Sakuzaku
  module DatabaseRakeTasks
    SKIP_TABLES = ['schema_info', 'schema_migrations']

    def self.purge
      tables.each do |table_name|
        ActiveRecord::Base.connection.delete("DELETE FROM #{table_name}")
      end
    end

    def self.recreate
      [:drop, :create].each do |task|
        Rake::Task["db:#{task}"].invoke
      end
    end

    def self.recreate_all
      all_databases(:recreate, 'Recreating')
    end

    def self.migrate_all
      all_databases(:migrate, 'Migrating')
    end

    def self.reset_all
      all_databases('migrate:reset', 'Resetting')
    end

    def self.verify
      Rake::Task['db:migrate:reset'].invoke

      uncommitted_migrations.each do |migration|
        system("rake db:migrate:down VERSION=#{migration}")
      end

      system('rake db:migrate')
    end

    def self.export_fixtures
      fixture_directory = path('test', 'fixtures', RAILS_ENV)

      ActiveRecord::Base.establish_connection

      # Create the fixtures directory if it doesn't exist.
      Dir.mkdir(fixture_directory) unless File.exists?(fixture_directory)

      # Delete any existing fixture files.
      system("rm -f '#{fixture_directory}#{File::SEPARATOR}'*.yml")

      # Dump each table in the database to a separate YAML fixtures file.
      tables.each do |table_name|
        puts(table_name)
        i = 0

        File.open(File.join(fixture_directory, "#{table_name}.yml"), 'w') do |file|
          rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{table_name}")

          # Convert each row retrieved from the query into YAML.
          rows = rows.each_with_object({}) do |row, hash|
            hash["#{table_name}_#{i += 1}"] = row
          end

          file.write(rows.to_yaml)
        end
      end
    end

    protected

    def self.tables
      ActiveRecord::Base.connection.tables - SKIP_TABLES
    end

    def self.all_databases(task, message)
      ActiveRecord::Base.configurations.each do |environment, configuration|
        puts("#{message} #{environment}...")
        system("rake db:#{task} RAILS_ENV=#{environment}")
      end
    end

    def self.uncommitted_migrations
      migration_directory = path('db', 'migrate')
      migration_files = `git status --porcelain '#{migration_directory}' | awk '{if ($1 == \"??\" || $1 == \"A\") print $2}'`
      migration_files.split.collect { |filename| filename.match(/db#{File::SEPARATOR}migrate#{File::SEPARATOR}(.+).rb/)[1] }
    end

    def self.path(*arguments)
      File.join(RAILS_ROOT, *arguments)
    end
  end
end
