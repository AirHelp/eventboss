# frozen_string_literal: true

require "sentry/eventboss/helpers"

module Sentry
  module Eventboss
    class ClientMiddleware
      include Sentry::Eventboss::Helpers

      def call(payload, queue_name)
        return yield unless Sentry.initialized?

        # Set user context if available
        user = Sentry.get_current_scope.user
        payload["sentry_user"] = user unless user.empty?

        # Add trace propagation headers if configured
        if Sentry.configuration.eventboss.propagate_traces
          payload["trace_propagation_headers"] ||= Sentry.get_trace_propagation_headers
        end

        # Create a span for the publishing operation
        Sentry.with_child_span(op: "queue.publish", description: queue_name) do |span|
          set_span_data(span, id: generate_message_id, queue: queue_name)

          yield
        end
      end

      private

      def generate_message_id
        SecureRandom.hex(8)
      end
    end
  end
end
