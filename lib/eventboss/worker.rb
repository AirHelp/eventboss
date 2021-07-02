module Eventboss
  # Worker is part of a pool of workers, handles UnitOfWork lifecycle
  class Worker
    include Logging
    include SafeThread

    attr_reader :id

    def initialize(launcher, id, bus, restart_on: [Exception])
      @id = id
      @launcher = launcher
      @bus = bus
      @thread = nil
      @restart_on = restart_on
    end

    def start
      @thread = safe_thread(id, &method(:run))
    end

    def run
      while (work = @bus.pop)
        run_work(work)
      end
      @launcher.worker_stopped(self)
    rescue Eventboss::Shutdown
      @launcher.worker_stopped(self)
    rescue *@restart_on => exception
      handle_exception(exception, worker_id: id)
      # Restart the worker in case of hard exception
      # Message won't be delete from SQS and will be visible later
      @launcher.worker_stopped(self, restart: true)
    end

    def run_work(work)
      server_middleware.invoke(work) do
        work.run
      end
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

    def server_middleware
      Eventboss.configuration.server_middleware
    end
  end
end
