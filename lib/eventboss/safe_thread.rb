module Eventboss
  # SafeThread includes thread handling with automatic error reporting
  module SafeThread
    def safe_thread(name)
      Thread.new do
        begin
          Thread.current[:ah_eventboss_label] = name
          yield
        rescue Exception => exception
          handle_exception(exception, name: name)
          raise exception
        end
      end
    end

    def handle_exception(exception, context)
      context.freeze
      Eventboss.configuration.error_handlers.each do |handler|
        handler.call(exception, context)
      end
    end
  end
end
