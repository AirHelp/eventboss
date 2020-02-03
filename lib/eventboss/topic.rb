# frozen_string_literal: true

module Eventboss
  class Topic
    class << self
      def build_arn(event_name:, source_app: nil)
        [
          'arn:aws:sns',
          Eventboss.configuration.eventboss_region,
          Eventboss.configuration.eventboss_account_id,
          build_name(
            event_name: event_name,
            source_app: source_app
          )
        ].join(':')
      end

      def build_name(event_name:, source_app: nil)
        [
          Eventboss.configuration.sns_sqs_name_infix,
          source_app,
          event_name,
          Eventboss.env
        ].compact.join('-')
      end
    end
  end
end
