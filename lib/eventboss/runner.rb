module Eventboss
  class Runner
    extend Logging

    class << self
      def launch
        queues = Eventboss::QueueListener.list
        client = Eventboss.configuration.sqs_client
        config = Eventboss.configuration

        Eventboss::Instrumentation.add(queues)

        launcher = Launcher.new(queues, client, worker_count: config.concurrency)

        self_read = setup_signals([:SIGTERM])

        begin
          launcher.start
          handle_signals(self_read, launcher)
        rescue Interrupt
          launcher.stop
          exit 0
        end
      end

      def start
        configuration = Eventboss.configuration

        queue_listeners = Eventboss::QueueListener.list
        Eventboss::Instrumentation.add(queue_listeners)
        polling_strategy = configuration.polling_strategy.call(queue_listeners.keys)

        fetcher = Eventboss::Fetcher.new(configuration)
        executor = Concurrent.global_io_executor

        manager = Eventboss::Manager.new(
          fetcher,
          polling_strategy,
          executor,
          queue_listeners,
          configuration.concurrency,
          configuration.error_handlers
        )

        manager.start

        self_read = setup_signals([:SIGTERM])

        begin
          handle_signals(self_read)
        rescue Interrupt
          executor.shutdown
          executor.wait_for_termination
          exit 0
        end
      end

      private

      def setup_signals(signals)
        self_read, self_write = IO.pipe

        signals.each do |signal|
          trap signal do
            self_write.puts signal
          end
        end

        self_read
      end


      def handle_signals(self_read, launcher)
        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          logger.info("Received #{ signal } signal, gracefully shutdowning...", 'runner')

          launcher.stop
          exit 0
        end
      end
    end
  end
end
