# frozen_string_literal: true

require 'ostruct'

module Eventboss
  class Configuration
    OPTS_ALLOWED_IN_CONFIG_FILE = %i[
      concurrency
      sns_sqs_name_infix
      listeners
    ].freeze

    attr_writer :raise_on_missing_configuration,
      :error_handlers,
      :concurrency,
      :log_level,
      :logger,
      :sns_client,
      :sqs_client,
      :eventboss_region,
      :eventboss_app_name,
      :eventboss_account_id,
      :eventboss_use_default_credentials,
      :aws_access_key_id,
      :aws_container_authorization_token_file,
      :aws_secret_access_key,
      :aws_session_token,
      :aws_sns_endpoint,
      :aws_sqs_endpoint,
      :sns_sqs_name_infix,
      :listeners

    def raise_on_missing_configuration
      defined_or_default('raise_on_missing_configuration') { (ENV['EVENTBOSS_RAISE_ON_MISSING_CONFIGURATION'] || ENV['EVENTBUS_RAISE_ON_MISSING_CONFIGURATION'])&.downcase == 'true' }
    end

    def error_handlers
      defined_or_default('error_handlers') do
        [ErrorHandlers::Logger.new, ErrorHandlers::NonExistentQueueHandler.new].tap do |handlers|
          handlers << ErrorHandlers::DbConnectionDropHandler.new if defined?(::ActiveRecord::StatementInvalid)
          handlers << ErrorHandlers::DbConnectionNotEstablishedHandler.new if defined?(::ActiveRecord::ConnectionNotEstablished)
        end
      end
    end

    def concurrency
      defined_or_default('concurrency') do
        concurrency = ENV['EVENTBOSS_CONCURRENCY'] || ENV['EVENTBUS_CONCURRENCY']
        concurrency ? concurrency.to_i : 25
      end
    end

    def log_level
      defined_or_default('log_level') { :info }
    end

    def logger
      defined_or_default('logger') do
        ::Logger.new(STDOUT, level: Eventboss.configuration.log_level)
      end
    end

    def sns_client
      defined_or_default('sns_client') { Eventboss::SnsClient.new(self) }
    end

    def sqs_client
      defined_or_default('sqs_client') do
        options = {
          region: eventboss_region,
        }

        unless eventboss_use_default_credentials
          options[:credentials] = credentials
        end

        if aws_sqs_endpoint
          options[:endpoint] = aws_sqs_endpoint
        end

        Aws::SQS::Client.new(options)
      end
    end

    def credentials
      return Aws::Credentials.new(aws_access_key_id, aws_secret_access_key, aws_session_token) if development_mode?

      Aws::Credentials.new(
        aws_access_key_id,
        aws_secret_access_key
      )
    end

    def eventboss_region
      defined_or_default('eventboss_region') { ENV['EVENTBOSS_REGION'] || ENV['EVENTBUS_REGION'] }
    end

    def eventboss_app_name
      defined_or_default('eventboss_app_name') { ENV['EVENTBOSS_APP_NAME'] || ENV['EVENTBUS_APP_NAME'] }
    end

    def eventboss_account_id
      defined_or_default('eventboss_account_id') { ENV['EVENTBOSS_ACCOUNT_ID'] || ENV['EVENTBUS_ACCOUNT_ID'] }
    end

    def eventboss_use_default_credentials
      defined_or_default('eventboss_use_default_credentials') { ENV['EVENTBOSS_USE_DEFAULT_CREDENTIALS'] == 'true' }
    end

    def aws_container_authorization_token_file
      defined_or_default('aws_container_authorization_token_file') { ENV['AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE'] }
    end

    def aws_access_key_id
      defined_or_default('aws_access_key_id') { ENV['AWS_ACCESS_KEY_ID'] }
    end

    def aws_secret_access_key
      defined_or_default('aws_secret_access_key') { ENV['AWS_SECRET_ACCESS_KEY'] }
    end

    def aws_session_token
      defined_or_default('aws_session_token') { ENV['AWS_SESSION_TOKEN'] }
    end

    def aws_sqs_endpoint
      defined_or_default('aws_sqs_endpoint') { ENV['AWS_SQS_ENDPOINT'] }
    end

    def aws_sns_endpoint
      defined_or_default('aws_sns_endpoint') { ENV['AWS_SNS_ENDPOINT'] }
    end

    def sns_sqs_name_infix
      defined_or_default('sns_sqs_name_infix') { ENV['EVENTBOSS_SQS_SNS_NAME_INFIX'] || ENV['EVENTBUS_SQS_SNS_NAME_INFIX'] || 'eventboss' }
    end

    def listeners
      defined_or_default('listeners') { {} }
    end

    def development_mode?
      defined_or_default('development_mode') do
        (ENV['EVENTBOSS_DEVELOPMENT_MODE']&.downcase || ENV['EVENTBUS_DEVELOPMENT_MODE'])&.downcase == 'true'
      end
    end

    def server_middleware
      @server_middleware ||= Middleware::Chain.new
    end

    def sentry_configuration
      @sentry_configuration ||= begin
        # Try to use the new Sentry integration configuration if available
        if defined?(::Sentry) && ::Sentry.initialized? && defined?(::Sentry.configuration.eventboss)
          # Create a bridge to the new configuration structure
          SentryConfigurationBridge.new(::Sentry.configuration.eventboss)
        else
          # Fallback to the old configuration
          require 'eventboss/error_handlers/sentry/configuration'
          Eventboss::ErrorHandlers::Sentry::Configuration.new
        end
      rescue LoadError
        # Sentry not available, return a mock configuration
        OpenStruct.new(
          report_after_retries: false,
          capture_message_body: false,
          capture_message_headers: true,
          propagate_traces: true,
          performance_monitoring: true,
          excluded_listeners: [],
          max_message_body_size: 4096,
          excluded_listener?: proc { false }
        )
      end
    end
    
    # Bridge class to provide backward compatibility with old configuration interface
    class SentryConfigurationBridge
      def initialize(new_config)
        @new_config = new_config
      end
      
      def report_after_retries
        @new_config.report_after_job_retries
      end
      
      def capture_message_body
        @new_config.capture_job_body
      end
      
      def capture_message_headers
        @new_config.capture_headers
      end
      
      def propagate_traces
        @new_config.propagate_traces
      end
      
      def performance_monitoring
        @new_config.performance_monitoring
      end
      
      def excluded_listeners
        @new_config.excluded_listeners
      end
      
      def max_message_body_size
        @new_config.max_message_body_size
      end
      
      def excluded_listener?(listener_class)
        @new_config.excluded_listener?(listener_class)
      end
    end

    private

    def defined_or_default(variable_name)
      if instance_variable_defined?("@#{variable_name}")
        instance_variable_get("@#{variable_name}")
      else
        instance_variable_set("@#{variable_name}", yield) if block_given?
      end
    end
  end
end
