module Eventboss
  class Configuration
    attr_writer :raise_on_missing_configuration,
                :error_handlers,
                :concurrency,
                :log_level,
                :logger,
                :sns_client,
                :sqs_client,
                :eventboss_region,
                :eventboss_app_name,
                :eventboss_account_id,
                :aws_access_key_id,
                :aws_secret_access_key,
                :aws_sns_endpoint,
                :aws_sqs_endpoint,
                :sns_sqs_name_infix

    def raise_on_missing_configuration
      defined_or_default('raise_on_missing_configuration') { ENV['EVENTBUS_RAISE_ON_MISSING_CONFIGURATION']&.downcase == 'true' }
    end

    def error_handlers
      defined_or_default('error_handlers') { [ErrorHandlers::Logger.new] }
    end

    def concurrency
      defined_or_default('concurrency') { ENV['EVENTBUS_CONCURRENCY'] ? ENV['EVENTBUS_CONCURRENCY'].to_i : 25 }
    end

    def log_level
      defined_or_default('log_level') { :info }
    end

    def logger
      defined_or_default('logger') do
        ::Logger.new(STDOUT, level: Eventboss.configuration.log_level)
      end
    end

    def sns_client
      defined_or_default('sns_client') { Eventboss::SnsClient.new(self) }
    end

    def sqs_client
      defined_or_default('sqs_client') do
        options = {
          region: eventboss_region,
          credentials: Aws::Credentials.new(
            aws_access_key_id,
            aws_secret_access_key
          )
        }
        if aws_sqs_endpoint
          options[:endpoint] = aws_sqs_endpoint
        end

        Aws::SQS::Client.new(options)
      end
    end

    def eventboss_region
      defined_or_default('eventboss_region') { ENV['EVENTBUS_REGION'] }
    end

    def eventboss_app_name
      defined_or_default('eventboss_app_name') { ENV['EVENTBUS_APP_NAME'] }
    end

    def eventboss_account_id
      defined_or_default('eventboss_account_id') { ENV['EVENTBUS_ACCOUNT_ID'] }
    end

    def aws_access_key_id
      defined_or_default('aws_access_key_id') { ENV['AWS_ACCESS_KEY_ID'] }
    end

    def aws_secret_access_key
      defined_or_default('aws_secret_access_key') { ENV['AWS_SECRET_ACCESS_KEY'] }
    end

    def aws_sqs_endpoint
      defined_or_default('aws_sqs_endpoint') { ENV['AWS_SQS_ENDPOINT'] }
    end

    def aws_sns_endpoint
      defined_or_default('aws_sns_endpoint') { ENV['AWS_SNS_ENDPOINT'] }
    end

    def sns_sqs_name_infix
      defined_or_default('sns_sqs_name_infix') { ENV['EVENTBUS_SQS_SNS_NAME_INFIX'] || 'eventboss' }
    end

    private

    def defined_or_default(variable_name)
      if instance_variable_defined?("@#{variable_name}")
        instance_variable_get("@#{variable_name}")
      else
        instance_variable_set("@#{variable_name}", yield) if block_given?
      end
    end
  end
end
