module Eventboss
  module ErrorHandlers
    class NonExistentQueueHandler
      def call(exception, context = {})
        if exception.class == ::Aws::SQS::Errors::NonExistentQueue
          queue = context.fetch(:poller_id, "").sub('poller-', '')
          Eventboss.logger.error("Queue  doesn't exist: " + queue)
        end
      end
    end
  end
end
