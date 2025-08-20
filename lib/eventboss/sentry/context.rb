module Eventboss
  module Sentry
    class Context
      # since sentry has env selector, we can remove it from queue names
      QUEUES_WITHOUT_ENV = Hash.new do |hash, key|
        hash[key] = key
                      .gsub(/-#{Eventboss.env}-deadletter$/, '-ENV-deadletter')
                      .gsub(/-#{Eventboss.env}$/, '-ENV')
      end

      def self.queue_name_for_sentry(queue_name)
        QUEUES_WITHOUT_ENV[queue_name]
      end

      # Constructs SNS message attributes for Sentry trace propagation.
      def self.build_sns_message_attributes
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
end