module Eventboss
  # LongPoller fetches messages from SQS using Long Polling
  # http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-long-polling.html
  # It starts one thread per queue (handled by Launcher)
  class LongPoller
    include Logging
    include SafeThread

    TIME_WAIT = 10

    attr_reader :id, :queue, :listener

    def initialize(launcher, bus, client, queue, listener)
      @id = "poller-#{queue.name}"
      @launcher = launcher
      @bus = bus
      @client = client
      @queue = queue
      @listener = listener
      @thread = nil
      @stop = false
    end

    def start
      @thread = safe_thread(id, &method(:run))
    end

    def terminate(wait = false)
      @stop = true
      return unless @thread
      @thread.value if wait
    end

    def kill(wait = false)
      @stop = true
      return unless @thread
      @thread.value if wait

      # Force shutdown of poller, in case the loop is stuck
      @thread.raise Eventboss::Shutdown
      @thread.value if wait
    end

    def fetch_and_dispatch
      fetch_messages.each do |message|
        logger.debug(id) { "enqueueing message #{message.message_id}" }
        @bus << UnitOfWork.new(@client, queue, listener, message)
      rescue ClosedQueueError
        logger.info(id) { "skip message #{message.message_id} enqueuing due to closed queue" }
      end
    end

    def run
      fetch_and_dispatch until @stop
      @launcher.poller_stopped(self)
    rescue Eventboss::Shutdown
      @launcher.poller_stopped(self)
    rescue Aws::SQS::Errors::NonExistentQueue
      handle_exception(exception, poller_id: id)
      @launcher.poller_stopped(self)
    rescue StandardError => exception
      handle_exception(exception, poller_id: id)
      # Give a chance for temporary AWS errors to be resolved
      # Sleep guarantees against repeating fast failure errors
      sleep TIME_WAIT
      @launcher.poller_stopped(self, restart: @stop == false)
    end

    private

    def fetch_messages
      logger.debug(id) { 'fetching messages' }
      @client.receive_message(
        queue_url: queue.url,
        max_number_of_messages: 10,
        wait_time_seconds: TIME_WAIT
      ).messages
    end
  end
end
