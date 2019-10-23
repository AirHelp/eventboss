module Eventboss
  class QueueListener
    class << self
      def select(
        include: Eventboss.configuration.listeners[:include],
        exclude: Eventboss.configuration.listeners[:exclude]
      )
        listeners = list.values.map(&:name)

        listeners &= include if include
        listeners -= exclude if exclude

        list.select { |_queue, listener| listeners.include?(listener.name) }
      end

      private

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
    end
  end
end
