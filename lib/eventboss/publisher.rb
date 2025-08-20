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
      with_sentry_span do
        sns_client.publish(**build_sns_params(payload))
      end
    end

    private

    attr_reader :event_name, :sns_client, :configuration, :source

    def sentry_enabled?
      defined?(::Eventboss::Sentry::Integration) && ::Sentry.initialized?
    end

    def build_sns_params(payload)
      {
        topic_arn: Topic.build_arn(event_name: event_name, source_app: source),
        message: json_payload(payload),
        message_attributes: sentry_enabled? ? build_sns_message_attributes : {}
      }
    end

    def with_sentry_span
      return yield unless sentry_enabled?

      queue_name = Queue.build_name(destination: source, event_name: event_name, env: Eventboss.env, source_app: source)

      ::Sentry.with_child_span(op: 'queue.publish', description: "Eventboss push #{source}/#{event_name}") do |span|
        span.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, ::Eventboss::Sentry::Context.queue_name_for_sentry(queue_name))

        message = yield

        span.set_data(::Sentry::Span::DataConventions::MESSAGING_MESSAGE_ID, message.message_id)
        message
      end
    end

    def json_payload(payload)
      payload.is_a?(String) ? payload : payload.to_json
    end

    def build_sns_message_attributes
      ::Eventboss::Sentry::Context.build_sns_message_attributes
    end
  end
end