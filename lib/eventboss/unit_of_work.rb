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

      listener_instance = @listener.new
      if listener_instance.respond_to?(:receive)
        receive_method_params = listener_instance.method(:receive).parameters
        if [:key, :keyreq].include?(receive_method_params[0][0])
          @listener.required_params = receive_method_params.filter { |p| p[0] == :keyreq }.map { |p| p[1] }
          @listener.optional_params = receive_method_params.filter { |p| p[0] == :key }.map { |p| p[1] }
        end
      end
    end

    def run
      logger.debug(@message.message_id) { 'Started' }
      processor = @listener.new
      JSON.parse(@message.body).tap do |payload|
        if @listener.required_params
          processor.receive(**validate_and_symbolize_keys(payload, @listener.required_params, @listener.optional_params))
        else
          processor.receive(payload)
        end
      end
      logger.debug(@message.message_id) { 'Finished' }
    rescue StandardError => exception
      handle_exception(exception, processor: processor, message_id: @message.message_id)
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

    def validate_and_symbolize_keys(payload, required_params, optional_params)
      {}.tap do |symbolized_payload|
        payload.keys.each do |k|
          symkey = k.respond_to?(:to_sym) ? k.to_sym : k
          next unless required_params.include?(symkey) || optional_params.include?(symkey)
          symbolized_payload[symkey] = payload[k]
        end

        missing_params = required_params - symbolized_payload.keys
        raise ArgumentError, "Missing required params in payload #{missing_params}" if missing_params.size > 0
      end
    end
  end
end
