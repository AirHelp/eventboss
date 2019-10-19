module Eventboss
  # Worker is part of a pool of workers, handles UnitOfWork lifecycle
  class Worker
    include Logging
    include SafeThread

    attr_reader :id

    def initialize(launcher, id, bus)
      @id = "worker-#{id}"
      @launcher = launcher
      @bus = bus
      @thread = nil
    end

    def start
      @thread = safe_thread(id, &method(:run))
    end

    def run
      while (work = @bus.pop)
        work.run
      end
      @launcher.worker_stopped(self)
    rescue Eventboss::Shutdown
      @launcher.worker_stopped(self)
    rescue Exception => exception
      handle_exception(exception, worker_id: id)
      # Restart the worker in case of hard exception
      # Message won't be delete from SQS and will be visible later
      @launcher.worker_stopped(self, restart: true)
    end

    def terminate(wait = false)
      stop_token
      return unless @thread
      @thread.value if wait
    end

    def kill(wait = false)
      stop_token
      return unless @thread
      @thread.raise Eventboss::Shutdown
      @thread.value if wait
    end

    private

    # stops the loop, by enqueuing falsey value
    def stop_token
      @bus << nil
    end
  end
end
