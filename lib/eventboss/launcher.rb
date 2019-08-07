module Eventboss
  # Launcher manages lifecycle of queues and pollers threads
  class Launcher
    include Logging

    DEFAULT_SHUTDOWN_ATTEMPTS = 5
    DEFAULT_SHUTDOWN_DELAY = 5

    def initialize(queues, client, options = {})
      @options = options
      @queues = queues
      @client = client

      @lock = Mutex.new
      @bus = SizedQueue.new(@queues.size * 10)

      @pollers = Set.new
      @queues.each { |q, listener| @pollers << new_poller(q, listener) }

      @workers = Set.new
      worker_count.times { |id| @workers << new_worker(id) }
    end

    def start
      logger.info("Starting #{@workers.size} workers, #{@pollers.size} pollers", 'launcher')

      @pollers.each(&:start)
      @workers.each(&:start)
    end

    def stop
      logger.info('Gracefully shutdown', 'launcher')

      @bus.clear
      @pollers.each(&:terminate)
      @workers.each(&:terminate)

      wait_for_shutdown
      hard_shutdown
    end

    def hard_shutdown
      return if @pollers.empty? && @workers.empty?

      logger.info("Killing remaining #{@pollers.size} pollers, #{@workers.size} workers", 'launcher')
      @pollers.each(&:kill)
      @workers.each(&:kill)
    end

    def worker_stopped(worker, restart: false)
      @lock.synchronize do
        @workers.delete(worker)
        @workers << new_worker(worker.id).tap(&:start) if restart
      end
      logger.debug("Worker #{worker.id} stopped, restart: #{restart}", 'launcher')
    end

    def poller_stopped(poller, restart: false)
      @lock.synchronize do
        @pollers.delete(poller)
        @pollers << new_poller(poller.queue, poller.listener).tap(&:start) if restart
      end
      logger.debug("Poller #{poller.id} stopped, restart: #{restart}", 'launcher')
    end

    private

    def worker_count
      @options.fetch(:worker_count, [2, Concurrent.processor_count].max)
    end

    def new_worker(id)
      Worker.new(self, id, @client, @bus)
    end

    def new_poller(queue, listener)
      LongPoller.new(self, @bus, @client, queue, listener)
    end

    def wait_for_shutdown
      attempts = 0
      while @pollers.any? || @workers.any?
        break if (attempts += 1) > shutdown_attempts
        sleep shutdown_delay
        logger.info("Waiting for #{@pollers.size} pollers, #{@workers.size} workers", 'launcher')
      end
    end

    def shutdown_attempts
      Integer(@options[:shutdown_attempts] || DEFAULT_SHUTDOWN_ATTEMPTS)
    end

    def shutdown_delay
      Integer(@options[:shutdown_delay] || DEFAULT_SHUTDOWN_DELAY)
    end
  end
end
