module Eventboss
  module ErrorHandlers
    class Sentry
      def initialize
        warn "[DEPRECATED] Eventboss::ErrorHandlers::Sentry is deprecated. " \
             "Use Eventboss::Sentry::ErrorHandler instead. " \
             "For automatic configuration, require 'eventboss/sentry/configure'. " \
             "This class will be removed in a future version."
        super
      def call(exception, context = {})
        eventboss_context = { component: 'eventboss' }
        eventboss_context[:action] = context[:processor].class.to_s if context[:processor]

        ::Sentry.with_scope do |scope|
          scope.set_tags(
            context.merge(eventboss_context)
          )
          ::Sentry.capture_exception(exception)
        end
      end
    end
  end
end
