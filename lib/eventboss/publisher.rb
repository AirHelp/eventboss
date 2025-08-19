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
      if defined?(::Eventboss::Sentry::Integration) && ::Sentry.initialized?
        publish_with_sentry(payload)
      else
        publish_without_sentry(payload)
      end
    end

    private

    def publish_with_sentry(payload)
      topic_arn = Topic.build_arn(event_name: event_name, source_app: source)

      ::Sentry.with_child_span(op: "queue.publish", description: "#{source}##{event_name}") do
        sns_client.publish(
          topic_arn: topic_arn,
          message: json_payload(payload),
          message_attributes: build_sentry_message_attributes
        )
      end
    end

    def publish_without_sentry(payload)
      topic_arn = Topic.build_arn(event_name: event_name, source_app: source)
      sns_client.publish(
        topic_arn: topic_arn,
        message: json_payload(payload)
      )
    end

    private

    attr_reader :event_name, :sns_client, :configuration, :source

    def json_payload(payload)
      payload.is_a?(String) ? payload : payload.to_json
    end

    def build_sentry_message_attributes
      attributes = ::Sentry.get_trace_propagation_headers
                           .slice('sentry-trace', 'baggage')
                           .transform_values do |header_value|
        { string_value: header_value, data_type: 'String' }
      end
      user = ::Sentry.get_current_scope.user
      if user && !user.empty?
        attributes['sentry_user'] = {
          string_value: user.to_json,
          data_type: 'String'
        }
      end
      attributes
    end
  end
end
