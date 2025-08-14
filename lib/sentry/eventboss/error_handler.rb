# frozen_string_literal: true

require "sentry/eventboss/context_filter"

module Sentry
  module Eventboss
    class ErrorHandler
      # @param exception [Exception] the exception / error that occurred
      # @param context [Hash] Eventboss error context from UnitOfWork
      def call(exception, context = {})
        return unless Sentry.initialized?

        context_filter = Sentry::Eventboss::ContextFilter.new(context)

        scope = Sentry.get_current_scope
        scope.set_transaction_name(context_filter.transaction_name, source: :task) unless scope.transaction_name

        # Check if this listener should be excluded
        if listener_class = context[:listener_class]
          return if Sentry.configuration.eventboss.excluded_listener?(listener_class)
        end

        # If Sentry is configured to only report an error _after_ all retries have been exhausted,
        # and if the job is retryable, check if we should skip this report
        if Sentry.configuration.eventboss.report_after_job_retries && retryable?(context)
          # For SQS-based queues, we can use ApproximateReceiveCount to determine retry state
          receive_count = context[:approximate_receive_count] || context[:retry_count] || 1
          max_retries = context[:max_retries] || 3
          
          if receive_count < max_retries
            return
          end
        end

        Sentry::Eventboss.capture_exception(
          exception,
          contexts: { eventboss: context_filter.filtered },
          hint: { background: false }
        )
      ensure
        scope&.clear
      end

      private

      def retryable?(context)
        # For Eventboss, messages are retryable by default via SQS visibility timeout
        # unless explicitly marked as non-retryable
        !context[:non_retryable]
      end
    end
  end
end
