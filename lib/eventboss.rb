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
require 'eventboss/middleware'
require 'eventboss/unit_of_work'
require 'eventboss/worker'
require 'eventboss/fetcher'
require 'eventboss/publisher'
require 'eventboss/sender'
require 'eventboss/topic'
require 'eventboss/runner'
require 'eventboss/extensions'
require 'eventboss/development_mode'

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
      sns_client = configuration.sns_client

      if configuration.development_mode?
        source_app = configuration.eventboss_app_name unless opts[:generic]
        topic_name = Topic.build_name(event_name: event_name, source_app: source_app)
        sns_client.create_topic(name: topic_name)
      end

      Publisher.new(event_name, sns_client, configuration, opts)
    end

    def sender(event_name, destination, options = {})
      source_app = configuration.eventboss_app_name unless options[:generic]
      queue = Queue.build(
        destination: destination,
        source_app: source_app,
        event_name: event_name,
        env: env
      )
      sqs_client = configuration.sqs_client

      if configuration.development_mode?
        sqs_client.create_queue(queue_name: queue.name)
      end

      Sender.new(
        client: sqs_client,
        queue: queue
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

# Auto-load Sentry integration if Sentry is available
begin
  require 'sentry-ruby'
  require 'sentry-eventboss'
rescue LoadError
  # Sentry not available, skip integration
end
