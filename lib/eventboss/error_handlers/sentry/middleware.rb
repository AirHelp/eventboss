# frozen_string_literal: true

require "eventboss/error_handlers/sentry/context_filter"
require "eventboss/error_handlers/sentry/helpers"

module Eventboss
  module ErrorHandlers
    class Sentry
      class Middleware
        include Eventboss::ErrorHandlers::Sentry::Helpers

        OP_NAME = "queue.process"
        SPAN_ORIGIN = "auto.queue.eventboss"

# frozen_string_literal: true

# DEPRECATED: This middleware is deprecated in favor of Sentry::Eventboss::Middleware
# It's kept for backward compatibility but will be removed in future versions.
# Please use the new integration by requiring 'sentry-eventboss' instead.

require "eventboss/error_handlers/sentry/context_filter"
require "eventboss/error_handlers/sentry/helpers"

module Eventboss
  module ErrorHandlers
    class Sentry
      class Middleware
        include Eventboss::ErrorHandlers::Sentry::Helpers

        OP_NAME = "queue.process"
        SPAN_ORIGIN = "auto.queue.eventboss"

        def call(work)
          return yield unless ::Sentry.initialized?

          # Try to delegate to the new Sentry integration if available
          if defined?(::Sentry::Eventboss::Middleware)
            middleware = ::Sentry::Eventboss::Middleware.new
            return middleware.call(work) { yield }
          end

          # Fallback to legacy behavior
          legacy_call(work) { yield }
        end

        private

        def legacy_call(work)
          context_filter = Eventboss::ErrorHandlers::Sentry::ContextFilter.new(work.context)

          ::Sentry.clone_hub_to_current_thread
          scope = ::Sentry.get_current_scope
          
          # Set basic tags and context
          scope.set_tags(
            queue: work.queue_name,
            event: work.event_name,
            source_app: work.source_app,
            component: 'eventboss'
          )
          
          # Set rich context data
          scope.set_contexts(eventboss: context_filter.filtered)
          scope.set_transaction_name(context_filter.transaction_name, source: :task)
          
          # Start performance transaction
          transaction = start_transaction(scope, work.headers)

          if transaction
            scope.set_span(transaction)

            latency = calculate_latency(work)
            
            set_span_data(
              transaction,
              id: work.message_id,
              queue: work.queue_name,
              event: work.event_name,
              latency: latency,
              retry_count: work.retry_count || 0,
              message_size: work.body&.bytesize
            )
          end

          begin
            yield
          rescue => exception
            finish_transaction(transaction, 500)
            raise
          end

          finish_transaction(transaction, 200)
          # Clear scope after successful processing
          scope.clear
        end

        def start_transaction(scope, headers)
          options = {
            name: scope.transaction_name,
            source: scope.transaction_source,
            op: OP_NAME,
            origin: SPAN_ORIGIN
          }

          # Extract trace propagation headers if available
          env = extract_trace_headers(headers)
          transaction = ::Sentry.continue_trace(env, **options)
          ::Sentry.start_transaction(transaction: transaction, **options)
        end

        def finish_transaction(transaction, status)
          return unless transaction

          transaction.set_http_status(status)
          transaction.finish
        end

        def extract_trace_headers(headers)
          return {} unless headers&.is_a?(Hash)
          
          # Assume headers are lowercase - simple hash lookup
          headers.slice('sentry-trace', 'baggage')
        end
      end
    end
  end
end
