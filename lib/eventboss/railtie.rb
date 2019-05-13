class Eventboss::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/eventboss.rake'
  end
end
