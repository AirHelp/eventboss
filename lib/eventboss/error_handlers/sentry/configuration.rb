# frozen_string_literal: true

module Eventboss
  module ErrorHandlers
    class Sentry
      class Configuration
        # Set this option to true if you want Sentry to only capture the last processing
        # attempt if it fails (based on message visibility timeout retries).
        attr_accessor :report_after_retries

        # Whether to capture the message body in error context
        attr_accessor :capture_message_body

        # Whether to capture message headers/attributes in error context  
        attr_accessor :capture_message_headers

        # Whether to inject trace propagation headers when publishing/sending messages
        attr_accessor :propagate_traces

        # Whether to enable performance monitoring for job processing
        attr_accessor :performance_monitoring

        # List of listener classes to exclude from Sentry reporting
        attr_accessor :excluded_listeners

        # Maximum message body size to capture (in bytes)
        attr_accessor :max_message_body_size

        def initialize
          @report_after_retries = false
          @capture_message_body = false
          @capture_message_headers = true
          @propagate_traces = true
          @performance_monitoring = true
          @excluded_listeners = []
          @max_message_body_size = 4096 # 4KB limit by default
        end

        def excluded_listener?(listener_class)
          excluded_listeners.any? do |excluded|
            case excluded
            when String
              listener_class.to_s == excluded
            when Class
              listener_class == excluded
            when Regexp
              listener_class.to_s.match?(excluded)
            else
              false
            end
          end
        end
      end
    end
  end
end
