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
      def eventboss_options(opts)
        source_app = opts[:source_app] ? "#{opts[:source_app]}-" : ""
        event_name = opts[:event_name]

        ACTIVE_LISTENERS["#{source_app}#{event_name}"] = self
      end
    end
  end
end
