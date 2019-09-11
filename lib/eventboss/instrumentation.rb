module Eventboss
  # :nodoc:
  module Instrumentation
    def self.add(queue_listeners)
      return unless defined?(::NewRelic::Agent::Instrumentation::ControllerInstrumentation)
      Eventboss::Instrumentation::NewRelic.install(queue_listeners)
    end

    # :nodoc:
    module NewRelic
      def self.install(queue_listeners)
        Eventboss.logger.info('Loaded NewRelic instrumentation')
        queue_listeners.each_value do |listener_class|
          listener_class.include(::NewRelic::Agent::Instrumentation::ControllerInstrumentation)
          listener_class.add_transaction_tracer(:receive, category: 'OtherTransaction/EventbossJob')
        end

        Eventboss::Sender.include(::NewRelic::Agent::MethodTracer)
        Eventboss::Sender.add_method_tracer(:send_batch, 'Eventboss/sender_send_batch')

        Eventboss::Publisher.include(::NewRelic::Agent::MethodTracer)
        Eventboss::Publisher.add_method_tracer(:publish, 'Eventboss/publisher_publish')
      end
    end
  end
end
