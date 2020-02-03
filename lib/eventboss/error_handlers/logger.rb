module Eventboss
  module ErrorHandlers
    class Logger
      def call(exception, context = {})
        notice = {}.merge!(context)
        notice[:jid] = notice[:processor].jid if notice[:processor]
        notice[:processor] = notice[:processor].class.to_s if notice[:processor]
        Eventboss.logger.error(notice) do
          "Failure processing request: #{exception.message}"
        end
      end
    end
  end
end
