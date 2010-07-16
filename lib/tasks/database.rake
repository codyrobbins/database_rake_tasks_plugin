require('sakuzaku/database_rake_tasks')

namespace(:db) do
  desc("Removes all the data from the current environment's database, but does not drop the database itself.")
  task(:purge => :environment) do
    Sakuzaku::DatabaseRakeTasks.purge
  end

  desc("Drops and then recreates the current environment's database.")
  task(:recreate => :environment) do
    Sakuzaku::DatabaseRakeTasks.recreate
  end

  namespace(:recreate) do
    desc("Drops and then recreates all databases.")
    task(:all => :environment) do
      Sakuzaku::DatabaseRakeTasks.recreate_all
    end
  end

  namespace(:migrate) do
    desc('Migrates all databases. Target specific version with VERSION=x. Turn off output with VERBOSE=false.')
    task(:all => :environment) do
      Sakuzaku::DatabaseRakeTasks.migrate_all
    end

    namespace(:reset) do
      desc('Recreates all databases by running all migrations.')
      task(:all => :environment) do
        Sakuzaku::DatabaseRakeTasks.reset_all
      end
    end

    desc("Tests any uncommitted migrations by resetting the current environment's database, migrating all uncommitted migrations down, and then migrating up again.")
    task(:verify => :environment) do
      Sakuzaku::DatabaseRakeTasks.verify
    end
  end

  namespace(:fixtures) do
    desc("Create YAML test fixtures from the data in the current environment's database.")
    task(:export => :environment) do
      Sakuzaku::DatabaseRakeTasks.export_fixtures
    end
  end
end