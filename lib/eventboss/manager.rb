module Eventboss
  class Manager
    MIN_DISPATCH_INTERVAL = 0.1

    def initialize(fetcher, polling_strategy, executor, queue_listeners, concurrency, error_handlers)
      @fetcher          = fetcher
      @polling_strategy = polling_strategy
      @max_processors   = concurrency
      @busy_processors  = Concurrent::AtomicFixnum.new(0)
      @executor         = executor
      @queue_listeners  = queue_listeners
      @error_handlers   = Array(error_handlers)
    end

    def start
      Eventboss::Logger.debug('Starting dispatch loop...')

      dispatch_loop
    end

    private

    def running?
      @executor.running?
    end

    def dispatch_loop
      return unless running?

      Eventboss::Logger.debug('Posting task to executor')

      @executor.post { dispatch }
    end

    def dispatch
      return unless running?

      if ready <= 0 || (queue = @polling_strategy.next_queue).nil?
        return sleep(MIN_DISPATCH_INTERVAL)
      end
      dispatch_single_messages(queue)
    rescue => ex
      handle_dispatch_error(ex)
    ensure
      Eventboss::Logger.debug('Ensuring dispatch loop')
      dispatch_loop
    end

    def busy
      @busy_processors.value
    end

    def ready
      @max_processors - busy
    end

    def processor_done(processor)
      Eventboss::Logger.info("Success", processor.jid)
      @busy_processors.decrement
    end

    def processor_error(processor, exception)
      @error_handlers.each { |handler| handler.call(exception, processor) }
      @busy_processors.decrement
    end

    def assign(queue, sqs_msg)
      return unless running?

      @busy_processors.increment
      processor = @queue_listeners[queue].new

      Concurrent::Promise.execute(executor: @executor) do
        body = JSON.parse(sqs_msg.body) rescue sqs_msg.body
        Eventboss::Logger.info("Started", processor.jid)
        processor.receive(body)
      end.then do
        cleanup(processor)
        postpone_if_needed(queue, sqs_msg, processor) || delete_from_queue(queue, sqs_msg)
        processor_done(processor)
      end.rescue do |e|
        cleanup(processor)
        postpone_if_needed(queue, sqs_msg, processor)
        processor_error(processor, e)
      end
    end

    def cleanup(_processor)
      if defined?(ActiveRecord)
        ::ActiveRecord::Base.clear_active_connections!
      end
    end

    def delete_from_queue(queue, sqs_msg)
      @fetcher.delete(queue, sqs_msg)
    end

    def postpone_if_needed(queue, sqs_msg, processor)
      return false unless processor.postponed_by
      @fetcher.change_message_visibility(queue, sqs_msg, processor.postponed_by)
    rescue => error
      Eventboss::Logger.info("Could not postpone message #{error.message}", processor.jid)
    end

    def dispatch_single_messages(queue)
      messages = @fetcher.fetch(queue, ready)
      @polling_strategy.messages_found(queue, messages.size)
      messages.each { |message| assign(queue, message) }
    end

    def handle_dispatch_error(ex)
      Eventboss::Logger.error("Error dispatching #{ex.message}")
      Process.kill('USR1', Process.pid)
    end
  end
end
