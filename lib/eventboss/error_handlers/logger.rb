module Eventboss
  module ErrorHandlers
    class Logger
      def call(exception, context = {})
        notice = {}.merge!(context)
        notice[:jid] = notice[:processor].jid if notice[:processor]
        notice[:processor] = notice[:processor].class.to_s if notice[:processor]
        Eventboss::Logger.error("Failure processing request #{exception.message}", notice)
      end
    end
  end
end
