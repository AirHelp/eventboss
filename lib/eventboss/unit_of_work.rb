module Eventboss
  # UnitOfWork handles calls a listener for each message and deletes on success
  class UnitOfWork
    include Logging
    include SafeThread

    attr_accessor :queue, :listener, :message

    def initialize(queue, listener, message)
      @queue = queue
      @listener = listener
      @message = message
    end

    def run(client)
      logger.debug('Started', @message.message_id)
      processor = @listener.new
      processor.receive(JSON.parse(@message.body))
      logger.info('Finished', @message.message_id)
    rescue StandardError => exception
      handle_exception(exception, processor: processor, message_id: @message.message_id)
    else
      cleanup(client)
    end

    def cleanup(client)
      client.delete_message(
        queue_url: @queue.url, receipt_handle: @message.receipt_handle
      )
      logger.debug('Deleting', @message.message_id)
    end
  end
end
