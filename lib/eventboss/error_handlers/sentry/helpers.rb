# frozen_string_literal: true

module Eventboss
  module ErrorHandlers
    class Sentry
      module Helpers
# frozen_string_literal: true

# DEPRECATED: This file is deprecated in favor of /lib/sentry/eventboss/helpers.rb
# It's kept for backward compatibility but will be removed in future versions.

module Eventboss
  module ErrorHandlers
    class Sentry
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
          return nil unless work.respond_to?(:enqueued_at) && work.enqueued_at

          begin
            enqueued_time = parse_time(work.enqueued_at)
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

        private

        def parse_time(time_value)
          case time_value
          when Time
            time_value
          when String
            Time.parse(time_value)
          when Numeric
            Time.at(time_value)
          else
            raise ArgumentError, "Unable to parse time from #{time_value.class}"
          end
        end
      end
    end
  end
end
