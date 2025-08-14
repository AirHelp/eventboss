# frozen_string_literal: true

# DEPRECATED: This error handler is deprecated in favor of Sentry::Eventboss::ErrorHandler
# It's kept for backward compatibility but will be removed in future versions.
# Please use the new integration by requiring 'sentry-eventboss' instead.

require "eventboss/error_handlers/sentry/context_filter"

module Eventboss
  module ErrorHandlers
    class Sentry
      def call(exception, context = {})
        return unless ::Sentry.initialized?

        # Try to delegate to the new Sentry integration if available
        if defined?(::Sentry::Eventboss::ErrorHandler)
          handler = ::Sentry::Eventboss::ErrorHandler.new
          return handler.call(exception, context)
        end

        # Fallback to legacy behavior
        legacy_call(exception, context)
      end

      private

      def legacy_call(exception, context)
        # Check if this listener should be excluded
        config = Eventboss.configuration.sentry_configuration
        if listener_class = context[:listener_class]
          return if config.excluded_listener?(listener_class)
        end

        # Check if we should only report after retries are exhausted
        if config.report_after_retries && should_skip_due_to_retries?(context)
          return
        end

        # Check if we're within a Sentry scope (set by middleware)
        scope = ::Sentry.get_current_scope
        
        if scope.transaction_name
          # We're within a transaction scope set by middleware
          # Just capture the exception with the existing context
          ::Sentry.capture_exception(exception, hint: { background: false })
        else
          # Fallback for when middleware is not used
          # Create a new scope with the context (legacy behavior)
          context_filter = Eventboss::ErrorHandlers::Sentry::ContextFilter.new(context)

          ::Sentry.with_scope do |fallback_scope|
            fallback_scope.set_transaction_name(context_filter.transaction_name, source: :task)
            fallback_scope.set_context(:eventboss, context_filter.filtered)
            fallback_scope.set_tags(component: 'eventboss')

            # Add basic context from error handler
            if context[:queue_name]
              fallback_scope.set_tags(queue: context[:queue_name])
            end
            if context[:message_id]
              fallback_scope.set_tags(message_id: context[:message_id])
            end

            ::Sentry.capture_exception(exception, hint: { background: false })
          end
        end
      end

      def should_skip_due_to_retries?(context)
        # This is a simplified retry detection - in a real implementation,
        # you might want to integrate with SQS's VisibilityTimeout and 
        # ApproximateReceiveCount to determine if retries are exhausted
        retry_count = context[:retry_count] || 0
        max_retries = context[:max_retries] || 3
        
        # Only report if this is the last retry attempt
        retry_count < max_retries
      end
    end
  end
end
