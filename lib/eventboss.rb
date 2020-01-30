require 'aws-sdk-sqs'
require 'aws-sdk-sns'
require 'securerandom'

require 'eventboss/version'
require 'eventboss/configuration'
require 'eventboss/instrumentation'
require 'eventboss/sns_client'
require 'eventboss/queue'
require 'eventboss/queue_listener'
require 'eventboss/listener'
require 'eventboss/logging'
require 'eventboss/safe_thread'
require 'eventboss/launcher'
require 'eventboss/long_poller'
require 'eventboss/unit_of_work'
require 'eventboss/worker'
require 'eventboss/fetcher'
require 'eventboss/publisher'
require 'eventboss/sender'
require 'eventboss/runner'
require 'eventboss/extensions'

# For Rails use railtie, for plain Ruby apps use custom scripts loader
if defined?(Rails)
  require 'eventboss/railtie'
else
  require 'eventboss/scripts'
end

module Eventboss
  Shutdown = Class.new(StandardError)

  class << self
    def publisher(event_name, opts = {})
      Publisher.new(event_name, configuration.sns_client, configuration, opts)
    end

    def sender(event_name, destination_app, options = {})
      queue_name = Queue.build_name(
        destination: destination_app,
        source: configuration.eventboss_app_name,
        event: event_name,
        env: env,
        generic: options[:generic]
      )

      Sender.new(
        client: configuration.sqs_client,
        queue: Queue.new(queue_name)
      )
    end

    def launch
      Eventboss::Runner.launch
    end

    def env
      @env ||= ENV['EVENTBOSS_ENV'] || ENV['EVENTBUS_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV']
    end

    def configure
      yield configuration if block_given?
    end

    def configuration
      @_configuration ||= Configuration.new
    end

    def logger
      Thread.current[:ah_eventboss_logger] ||= configuration.logger
    end
  end
end
