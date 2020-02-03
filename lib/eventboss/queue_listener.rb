module Eventboss
  class QueueListener
    class << self
      def select(include: nil, exclude: nil)
        listeners = list.values.map(&:name)

        listeners &= include if include
        listeners -= exclude if exclude

        list.select { |_queue, listener| listeners.include?(listener.name) }
      end

      private

      def list
        Eventboss::Listener::ACTIVE_LISTENERS.each_with_object({}) do |(eventboss_options, listener), queue_listeners|
          queue = Eventboss::Queue.build(
            destination: eventboss_options[:destination_app] || Eventboss.configuration.eventboss_app_name,
            source_app: eventboss_options[:source_app],
            event_name: eventboss_options[:event_name],
            env: Eventboss.env
          )
          queue_listeners[queue] = listener
        end
      end
    end
  end
end
