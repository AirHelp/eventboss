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

    def send_message(payload)
      message_attributes = build_message_attributes
      
      client.send_message(
        queue_url: queue.url,
        message_body: payload.to_json,
        message_attributes: message_attributes
      )
    end

    private

    attr_reader :queue, :client

    def build_entries(messages)
      message_attributes = build_message_attributes
      
      messages.map do |message|
        { 
          id: SecureRandom.hex, 
          message_body: message.to_json,
          message_attributes: message_attributes
        }
      end
    end

    def build_message_attributes
      attributes = {}
      
      # Add trace propagation headers if Sentry is available and configured
      if should_propagate_traces?
        trace_headers = ::Sentry.get_trace_propagation_headers
        
        if trace_headers['sentry-trace']
          attributes['sentry-trace'] = {
            string_value: trace_headers['sentry-trace'],
            data_type: 'String'
          }
        end
        
        if trace_headers['baggage']
          attributes['baggage'] = {
            string_value: trace_headers['baggage'],
            data_type: 'String'
          }
        end
      end
      
      attributes
    end

    def should_propagate_traces?
      # Access configuration through Eventboss module
      defined?(::Sentry) && 
        ::Sentry.initialized? && 
        ::Sentry.configuration.eventboss.propagate_traces
    end
  end
end
