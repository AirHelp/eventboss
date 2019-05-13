module Eventboss
  module Polling
    class Basic
      PAUSE_AFTER_EMPTY = 2 # seconds

      def initialize(queues, timer = Time)
        @queues = queues.to_a
        @timer = timer
        @paused_until = @queues.each_with_object(Hash.new) do |queue, hash|
          hash[queue] = @timer.at(0)
        end

        reset_next_queue
      end

      def next_queue
        next_active_queue
      end

      def messages_found(queue, messages_count)
        if messages_count == 0
          pause(queue)
        else
          reset_next_queue
        end
      end

      def active_queues
        @queues.reject { |q, _| queue_paused?(q) }
      end

      private

      def next_active_queue
        reset_next_queue if queues_unpaused_since?

        size = @queues.length
        size.times do
          queue = @queues[@next_queue_index]
          @next_queue_index = (@next_queue_index + 1) % size
          return queue unless queue_paused?(queue)
        end

        nil
      end

      def queues_unpaused_since?
        last = @last_unpause_check
        now = @last_unpause_check = @timer.now

        last && @paused_until.values.any? { |t| t > last && t <= now }
      end

      def reset_next_queue
        @next_queue_index = 0
      end

      def queue_paused?(queue)
        @paused_until[queue] > @timer.now
      end

      def pause(queue)
        return unless PAUSE_AFTER_EMPTY > 0
        @paused_until[queue] = @timer.now + PAUSE_AFTER_EMPTY
      end
    end
  end
end
