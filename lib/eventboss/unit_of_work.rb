module Eventboss
  # UnitOfWork handles calls a listener for each message and deletes on success
  class UnitOfWork
    include Logging
    include SafeThread

    attr_accessor :queue, :listener, :message

    def initialize(client, queue, listener, message)
      @client = client
      @queue = queue
      @listener = listener
      @message = message
      @logger = logger
    end

    def run
      started_at = Time.current
      logger.debug(@message.message_id) { 'Started' }
      processor = @listener.new
      processor.receive(JSON.parse(@message.body))
      logger.debug(@message.message_id) { 'Finished' }
    rescue StandardError => exception
      context = build_error_context(processor, started_at)
      handle_exception(exception, context)
    else
      cleanup unless processor.postponed_by
    ensure
      change_message_visibility(processor.postponed_by) if processor.postponed_by
    end

    def change_message_visibility(postponed_by)
      @client.change_message_visibility(
        queue_url: @queue.url,
        receipt_handle: @message.receipt_handle,
        visibility_timeout: postponed_by
      )
    end

    def cleanup
      @client.delete_message(
        queue_url: @queue.url, receipt_handle: @message.receipt_handle
      )
      logger.debug(@message.message_id) { 'Deleting' }
    end

    private

    def build_error_context(processor, started_at)
      {
        processor: processor,
        message_id: @message.message_id,
        queue_name: @queue.name,
        listener_class: @listener.to_s,
        processing_started_at: started_at,
        processing_duration: Time.current.to_f - started_at.to_f
      }
    end

    def extract_message_attributes
      return {} unless @message.respond_to?(:attributes) && @message.attributes

      @message.attributes
    rescue => e
      { extraction_error: e.message }
    end
  end
end
