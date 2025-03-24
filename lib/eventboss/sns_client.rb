# frozen_string_literal: true

module Eventboss
  class NotConfigured < StandardError;
  end

  class SnsClient
    def initialize(configuration)
      @configuration = configuration
    end

    def publish(payload)
      backend.publish(payload)
    end

    def create_topic(name:)
      backend.create_topic(name: name)
    end

    def create_subscription(topic_arn:, queue_arn:)
      subscription = backend.subscribe(
        topic_arn: topic_arn,
        endpoint: queue_arn,
        protocol: 'sqs'
      )
      set_raw_message_delivery(subscription)
    end

    private

    attr_reader :configuration

    def set_raw_message_delivery(subscription)
      backend.set_subscription_attributes(
        subscription_arn: subscription.subscription_arn,
        attribute_name: 'RawMessageDelivery',
        attribute_value: 'true'
      )
    end

    def backend
      if configured?
        options = {
          region: configuration.eventboss_region,
        }

        unless configuration.eventboss_use_default_credentials
          options[:credentials] = credentials
        end

        if configuration.aws_sns_endpoint
          options[:endpoint] = configuration.aws_sns_endpoint
        end

        Aws::SNS::Client.new(options)
      elsif configuration.raise_on_missing_configuration
        raise NotConfigured, 'Eventboss is not configured.'
      else
        Mock.new
      end
    end

    def credentials
      return ::Aws::Credentials.new(
        configuration.aws_access_key_id,
        configuration.aws_secret_access_key,
        configuration.aws_session_token
      ) if configuration.development_mode?

      ::Aws::Credentials.new(
        configuration.aws_access_key_id,
        configuration.aws_secret_access_key
      )
    end

    def configured?
      !!(
        configuration.eventboss_region &&
        configuration.eventboss_account_id &&
        configuration.eventboss_app_name
      )
    end

    class Mock
      def publish(_)
        Eventboss.logger.info('Eventboss is not configured. Skipping message publishing!')
        return
      end
    end
  end

end
