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
          logger.info('runner') { "Received #{ signal } signal, gracefully shutdowning..." }

          launcher.stop
          exit 0
        end
      end
    end
  end
end
