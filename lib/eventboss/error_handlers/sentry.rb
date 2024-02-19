module Eventboss
  module ErrorHandlers
    class Sentry
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
