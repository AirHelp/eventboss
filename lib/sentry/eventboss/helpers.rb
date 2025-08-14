# frozen_string_literal: true

module Sentry
  module Eventboss
    module Helpers
      def set_span_data(span, id:, queue:, event: nil, latency: nil, retry_count: nil, message_size: nil)
        return unless span

        # Use Sentry's data conventions for messaging
        span.set_data("messaging.message.id", id) if id
        span.set_data("messaging.destination.name", queue) if queue
        span.set_data("messaging.operation", "process")
        span.set_data("messaging.system", "eventboss")
        
        # Eventboss-specific data
        span.set_data("eventboss.event_name", event) if event
        span.set_data("eventboss.retry_count", retry_count) if retry_count
        span.set_data("eventboss.message_size", message_size) if message_size
        
        # Timing data
        if latency
          span.set_data("messaging.message.receive.latency", latency)
        end
      end

      def calculate_latency(work)
        return nil unless work.respond_to?(:message) && work.message

        # Try to extract enqueued time from SQS message attributes
        message = work.message
        return nil unless message.respond_to?(:attributes) && message.attributes
        
        sent_timestamp = message.attributes['SentTimestamp']
        return nil unless sent_timestamp

        begin
          # SQS SentTimestamp is in milliseconds
          enqueued_time = Time.at(sent_timestamp.to_i / 1000.0)
          current_time = Time.now
          
          # Return latency in milliseconds
          ((current_time - enqueued_time) * 1000).round
        rescue => e
          # If we can't calculate latency, just return nil
          nil
        end
      end

      def now_in_ms
        Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      end
    end
  end
end
