# frozen_string_literal: true

module Sentry
  module Eventboss
    class << self
      # Capture an exception with Eventboss-specific context
      # @param exception [Exception] the exception to capture
      # @param contexts [Hash] additional contexts to include
      # @param hint [Hash] additional hint data
      def capture_exception(exception, contexts: {}, hint: {})
        Sentry.with_scope do |scope|
          contexts.each do |key, value|
            scope.set_context(key, value)
          end

          # Set Eventboss-specific tags
          scope.set_tags(
            component: 'eventboss',
            eventboss_version: defined?(::Eventboss::VERSION) ? ::Eventboss::VERSION : 'unknown'
          )

          Sentry.capture_exception(exception, hint: hint)
        end
      end
    end
  end
end
