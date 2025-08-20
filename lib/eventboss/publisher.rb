# frozen_string_literal: true

module Eventboss
  class Publisher
    def initialize(event_name, sns_client, configuration, opts = {})
      @event_name = event_name
      @sns_client = sns_client
      @configuration = configuration
      @source = configuration.eventboss_app_name unless opts[:generic]
    end

    # Publishes the payload to the SNS topic.
    # If Sentry is enabled, it wraps the publish action in a Sentry span for tracing.
    def publish(payload)
      sns_params = build_sns_params(payload)
      publisher_action = -> { sns_client.publish(sns_params) }

      if sentry_enabled?
        with_sentry_span(&publisher_action)
      else
        publisher_action.call
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
        message_attributes: sentry_enabled? ? build_sentry_message_attributes : {}
      }
    end

    def with_sentry_span
      queue_name = Queue.build_name(destination: source, event_name: event_name, env: Eventboss.env, source_app: source)

      ::Sentry.with_child_span(op: 'queue.publish', description: "Eventboss push #{source}/#{event_name}") do |span|
        span.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, Eventboss::Sentry::ServerMiddleware::QUEUES_WITHOUT_ENV[queue_name])

        message = yield # Executes the publisher_action lambda

        span.set_data(::Sentry::Span::DataConventions::MESSAGING_MESSAGE_ID, message.message_id)
        message
      end
    end

    def json_payload(payload)
      payload.is_a?(String) ? payload : payload.to_json
    end

    # Constructs SNS message attributes for Sentry trace propagation.
    def build_sentry_message_attributes
      attributes = ::Sentry.get_trace_propagation_headers
                           .slice('sentry-trace', 'baggage')
                           .transform_values do |header_value|
        { string_value: header_value, data_type: 'String' }
      end

      user = ::Sentry.get_current_scope&.user
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