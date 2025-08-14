# frozen_string_literal: true

module Eventboss
  class Publisher
    def initialize(event_name, sns_client, configuration, opts = {})
      @event_name = event_name
      @sns_client = sns_client
      @configuration = configuration
      @source = configuration.eventboss_app_name unless opts[:generic]
    end

    def publish(payload)
      topic_arn = Topic.build_arn(event_name: event_name, source_app: source)
      
      # Inject trace propagation headers if Sentry is available and configured
      message_attributes = build_message_attributes

      sns_client.publish(
        topic_arn: topic_arn,
        message: json_payload(payload),
        message_attributes: message_attributes
      )
    end

    private

    attr_reader :event_name, :sns_client, :configuration, :source

    def json_payload(payload)
      payload.is_a?(String) ? payload : payload.to_json
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
      defined?(::Sentry) && 
        ::Sentry.initialized? && 
        ::Sentry.configuration.eventboss.propagate_traces
    end
  end
end
