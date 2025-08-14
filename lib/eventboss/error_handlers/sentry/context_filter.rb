# frozen_string_literal: true

module Eventboss
  module ErrorHandlers
    class Sentry
      class ContextFilter
        EVENTBOSS_NAME = "Eventboss"

        attr_reader :context

        def initialize(context)
          @context = context
        end

        def filtered
          # Create a rich context with job processing information
          filtered_context = {
            queue_name: context[:queue_name],
            event_name: context[:event_name],
            source_app: context[:source_app],
            destination_app: context[:destination_app],
            message_id: context[:message_id],
            retry_count: context[:retry_count] || 0,
            processing_attempts: context[:processing_attempts] || 1,
            enqueued_at: context[:enqueued_at],
            listener_class: context[:listener_class]&.to_s,
            processor: context[:processor]&.class&.to_s
          }

          # Add message body size if available
          if context[:body]
            filtered_context[:message_size] = context[:body].bytesize rescue nil
          end

          # Add timing information if available
          if context[:started_at]
            filtered_context[:started_at] = context[:started_at]
          end

          # Remove nil values to keep context clean
          filtered_context.compact
        end

        def transaction_name
          if processor = context[:processor]
            "#{EVENTBOSS_NAME}/#{processor.class}"
          elsif listener_class = context[:listener_class]
            "#{EVENTBOSS_NAME}/#{listener_class}"
          elsif queue_name = context[:queue_name]
            "#{EVENTBOSS_NAME}/#{queue_name}"
          else
            EVENTBOSS_NAME
          end
        end
      end
    end
  end
end
