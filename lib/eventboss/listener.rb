module Eventboss
  module Listener
    ACTIVE_LISTENERS = {}

    def self.included(base)
      base.extend ClassMethods
    end

    def jid
      @jid ||= SecureRandom.uuid
    end

    attr_reader :postponed_by

    def postpone_by(time_in_secs)
      @postponed_by = time_in_secs.to_i
    end

    module ClassMethods
      attr_reader :options

      def eventboss_options(options)
        @options = options.compact

        ACTIVE_LISTENERS[@options] = self
      end
    end
  end
end
