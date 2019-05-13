module Eventboss
  class QueueListener
    class << self
      def list
        Hash[Eventboss::Listener::ACTIVE_LISTENERS.map do |src_app_event, listener|
          [Eventboss::Queue.new("#{Eventboss.configuration.eventboss_app_name}#{Eventboss.configuration.sns_sqs_name_infix}#{src_app_event}-#{Eventboss.env}"), listener]
        end]
      end
    end
  end
end
