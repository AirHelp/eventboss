module Eventboss
  class Sender
    def initialize(client:, queue:)
      @client = client
      @queue = queue
    end

    def send_batch(payload)
      client.send_message_batch(
        queue_url: queue.url,
        entries: Array(build_entries(payload))
      )
    end

    private

    attr_reader :queue, :client

    def build_entries(messages)
      messages.map do |message|
        { id: SecureRandom.hex, message_body: message.to_json }
      end
    end
  end
end
