module Eventboss
  class Fetcher
    FETCH_LIMIT = 10 # maximum possible for SQS

    attr_reader :client

    def initialize(configuration)
      @client = configuration.sqs_client
    end

    def fetch(queue, limit)
      @client.receive_message(queue_url: queue.url, max_number_of_messages: max_no_of_messages(limit)).messages
    end

    def delete(queue, message)
      @client.delete_message(queue_url: queue.url, receipt_handle: message.receipt_handle)
    end

    def change_message_visibility(queue, message, visibility_timeout)
      @client.change_message_visibility(
        queue_url: queue.url,
        receipt_handle: message.receipt_handle,
        visibility_timeout: visibility_timeout
      )
    end

    private

    def max_no_of_messages(limit)
      [limit, FETCH_LIMIT].min
    end
  end
end
