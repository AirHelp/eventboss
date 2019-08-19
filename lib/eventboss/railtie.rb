class Eventboss::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/eventboss.rake'

    # Load rails environment before executing reload.
    # It makes sure to load configuration file.
    task 'eventboss:deadletter:reload': :environment
  end
end
