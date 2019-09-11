module Eventboss
  class NotConfigured < StandardError; end

  class SnsClient
    def initialize(configuration)
      @configuration = configuration
    end

    def publish(payload)
      backend.publish(payload)
    end

    private

    attr_reader :configuration

    def backend
      if configured?
        options = {
          region: configuration.eventboss_region,
          credentials: ::Aws::Credentials.new(
            configuration.aws_access_key_id,
            configuration.aws_secret_access_key
          )
        }
        if configuration.aws_sns_endpoint
          options[:endpoint] = configuration.aws_sns_endpoint
        end
        Aws::SNS::Client.new(
          options
        )
      elsif configuration.raise_on_missing_configuration
        raise NotConfigured, 'Eventboss is not configured'
      else
        Mock.new
      end
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
