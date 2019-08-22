# frozen_string_literal: true

module Eventboss
  class QueueListener
    class << self
      def list
        Eventboss::Listener::ACTIVE_LISTENERS.map do |src_app_event, listener|
          [Eventboss::Queue.new(src_app_event), listener]
        end.to_h
      end
    end
  end
end
