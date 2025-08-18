module Eventboss
  module Sentry
    class ErrorHandler
      def call(exception, _context = {})
        return unless ::Sentry.initialized?

        Eventboss::Sentry::Integration.capture_exception(
          exception,
          contexts: { eventboss: { } },
          hint: { background: false }
        )
      end
    end
  end
end
