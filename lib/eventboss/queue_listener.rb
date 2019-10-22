module Eventboss
  class QueueListener
    class << self
      def list
        Hash[Eventboss::Listener::ACTIVE_LISTENERS.map do |src_app_event, listener|
          [
            Eventboss::Queue.new(
              [
                Eventboss.configuration.eventboss_app_name,
                Eventboss.configuration.sns_sqs_name_infix,
                src_app_event,
                Eventboss.env
              ].join('-')
            ),
            listener
          ]
        end]
      end

      def list_active
        listeners = list.values.map(&:name)
        if Eventboss.configuration.listeners[:include]
          listeners &= Eventboss.configuration.listeners[:include]
        end

        if Eventboss.configuration.listeners[:exclude]
          listeners -= Eventboss.configuration.listeners[:exclude]
        end

        list.select { |_queue, listener| listeners.include?(listener.name) }
      end
    end
  end
end
