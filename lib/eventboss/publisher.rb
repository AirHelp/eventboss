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
  end
end
