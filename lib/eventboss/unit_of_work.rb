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
      @logger = logger
    end

    def run(client)
      logger.debug(@message.message_id) { 'Started' }
      processor = @listener.new
      processor.receive(JSON.parse(@message.body))
      logger.debug(@message.message_id) { 'Finished' }
    rescue StandardError => exception
      handle_exception(exception, processor: processor, message_id: @message.message_id)
    else
      cleanup(client) unless @listener.postponed_by
    ensure
      change_message_visibility(client) if @listener.postponed_by
    end

    def change_message_visibility(client)
      client.change_message_visibility(
        queue_url: @queue.url,
        receipt_handle: @message.receipt_handle,
        visibility_timeout: @listener.postponed_by
      )
    end

    def cleanup(client)
      client.delete_message(
        queue_url: @queue.url, receipt_handle: @message.receipt_handle
      )
      logger.debug(@message.message_id) { 'Deleting' }
    end
  end
end
