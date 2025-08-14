# frozen_string_literal: true

module Sentry
  class Configuration
    attr_reader :eventboss

    add_post_initialization_callback do
      @eventboss = Sentry::Eventboss::Configuration.new
      @excluded_exceptions = @excluded_exceptions.concat(Sentry::Eventboss::IGNORE_DEFAULT)
    end
  end

  module Eventboss
    IGNORE_DEFAULT = [
      "Eventboss::Shutdown"
    ]

    class Configuration
      # Set this option to true if you want Sentry to only capture the last job
      # retry if it fails (based on SQS message visibility timeout and approximate receive count).
      attr_accessor :report_after_job_retries

      # Whether we should inject headers while publishing messages in order to have a connected trace
      attr_accessor :propagate_traces

      # Capture message body in Sentry reports (be careful with sensitive data)
      attr_accessor :capture_job_body

      # Capture message headers in Sentry reports
      attr_accessor :capture_headers

      # List of listener classes to exclude from Sentry reporting
      attr_accessor :excluded_listeners

      # Enable performance monitoring for Eventboss jobs
      attr_accessor :performance_monitoring

      # Maximum message body size to capture (in bytes)
      attr_accessor :max_message_body_size

      def initialize
        @report_after_job_retries = false
        @propagate_traces = true
        @capture_job_body = false
        @capture_headers = true
        @excluded_listeners = []
        @performance_monitoring = true
        @max_message_body_size = 4096 # 4KB limit by default
      end

      def excluded_listener?(listener_class)
        listener_class_name = listener_class.to_s
        @excluded_listeners.any? do |excluded|
          case excluded
          when String
            excluded == listener_class_name
          when Class
            excluded == listener_class || listener_class < excluded
          when Regexp
            excluded.match?(listener_class_name)
          else
            false
          end
        end
      end
    end
  end
end
