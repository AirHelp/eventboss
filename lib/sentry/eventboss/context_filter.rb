# frozen_string_literal: true

require 'json'

module Sentry
  module Eventboss
    class ContextFilter
      EVENTBOSS_NAME = "Eventboss"

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def filtered
        filtered_context = filter_context(context)
        
        # Remove any potentially sensitive data based on configuration
        unless Sentry.configuration.eventboss.capture_job_body
          filtered_context.delete(:message_body)
          filtered_context.delete(:payload)
        end

        unless Sentry.configuration.eventboss.capture_headers
          filtered_context.delete(:message_attributes)
          filtered_context.delete(:headers)
        end

        # Limit message body size if present
        if filtered_context[:message_body] && Sentry.configuration.eventboss.max_message_body_size
          max_size = Sentry.configuration.eventboss.max_message_body_size
          if filtered_context[:message_body].bytesize > max_size
            filtered_context[:message_body] = "#{filtered_context[:message_body][0, max_size]}... [truncated]"
          end
        end

        filtered_context
      end

      def transaction_name
        listener_class = context[:listener_class] || context[:processor]&.class
        event_name = context[:event_name] || extract_event_from_message

        if listener_class
          "#{EVENTBOSS_NAME}/#{listener_class}"
        elsif event_name
          "#{EVENTBOSS_NAME}/#{event_name}"
        else
          EVENTBOSS_NAME
        end
      end

      private

      def filter_context(context)
        case context
        when Hash
          context.each_with_object({}) do |(k, v), memo|
            memo[k] = filter_context(v)
          end
        when Array
          context.map { |item| filter_context(item) }
        when String
          # Avoid logging very large strings
          if context.bytesize > 1000
            "#{context[0, 1000]}... [truncated]"
          else
            context
          end
        else
          context
        end
      end

      def extract_event_from_message
        # Try to extract event name from message body if it's JSON
        message_body = context[:message_body]
        return nil unless message_body

        begin
          parsed = JSON.parse(message_body)
          parsed['event'] || parsed['type'] || parsed['event_name']
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
