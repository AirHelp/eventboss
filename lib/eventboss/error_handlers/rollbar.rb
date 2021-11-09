module Eventboss
  module ErrorHandlers
    class Rollbar
      def call(exception, context = {})
        eventboss_context = { component: 'eventboss' }
        eventboss_context[:action] = context[:processor].class.to_s if context[:processor]

        default_options = { use_exception_level_filters: true }

        ::Rollbar.error(
          exception,
          context.merge(eventboss_context, default_options)
        )
      end
    end
  end
end
