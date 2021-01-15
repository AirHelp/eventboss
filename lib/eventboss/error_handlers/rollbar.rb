module Eventboss
  module ErrorHandlers
    class Rollbar
      def call(exception, context = {})
        eventboss_context = { component: 'eventboss' }
        eventboss_context[:action] = context[:processor].class.to_s if context[:processor]
        ::Rollbar.error(exception, eventboss_context.merge(context))
      end
    end
  end
end
