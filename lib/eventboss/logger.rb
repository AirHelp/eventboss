module Eventboss
  class Logger
    class << self
      def logger
        Thread.current[:ah_eventboss_logger] ||= ::Logger.new(
          STDOUT,
          level: Eventboss.configuration.log_level
        )
      end

      def info(msg, tag = nil)
        return unless logger
        logger.info(tagged(msg, tag))
      end

      def debug(msg, tag = nil)
        return unless logger
        logger.debug(tagged(msg, tag))
      end

      def error(msg, tag = nil)
        return unless logger
        logger.error(tagged(msg, tag))
      end

      private

      def tagged(msg, tag)
        return msg if tag.nil?
        msg.prepend("[#{tag}] ")
      end
    end
  end
end
