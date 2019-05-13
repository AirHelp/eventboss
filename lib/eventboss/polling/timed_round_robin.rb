module Eventboss
  module Polling
    class TimedRoundRobin
      PAUSE_AFTER_EMPTY = 2 # seconds

      def initialize(queues, timer = Time)
        @queues = queues.to_a
        @timer = timer
        @next_queue_index = 0
        @paused_until = @queues.each_with_object(Hash.new) do |queue, hash|
          hash[queue] = @timer.at(0)
        end
      end

      def next_queue
        size = @queues.length
        size.times do
          queue = @queues[@next_queue_index]
          @next_queue_index = (@next_queue_index + 1) % size
          return queue unless queue_paused?(queue)
        end

        nil
      end

      def messages_found(queue, messages_count)
        pause(queue) if messages_count == 0
      end

      private

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
