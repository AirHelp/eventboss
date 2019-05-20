module Eventboss
  class Publisher
    def initialize(event_name, sns_client, configuration, opts = {})
      @event_name = event_name
      @sns_client = sns_client
      @configuration = configuration
      @generic = opts[:generic]
    end

    def publish(payload)
      sns_client.publish({
        topic_arn: topic_arn,
        message: json_payload(payload)
      })
    end

    private

    attr_reader :event_name, :sns_client, :configuration

    def json_payload(payload)
      payload.is_a?(String) ? payload : payload.to_json
    end

    def topic_arn
      src_selector = @generic ? "" : "-#{configuration.eventboss_app_name}"

      "arn:aws:sns:#{configuration.eventboss_region}:#{configuration.eventboss_account_id}:\
#{Eventboss.configuration.sns_sqs_name_infix}#{src_selector}-#{event_name}-#{Eventboss.env}"
    end
  end
end
