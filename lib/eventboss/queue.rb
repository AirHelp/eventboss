# frozen_string_literal: true

module Eventboss
  class Queue
    include Comparable
    attr_reader :name

    class << self
      def build_name(destination:, event_name:, env:, source_app: nil)
        [
          destination,
          Eventboss.configuration.sns_sqs_name_infix,
          source_app,
          event_name,
          env
        ].compact.join('-')
      end

      def build(destination:, event_name:, env:, source_app: nil)
        name = build_name(
          destination: destination,
          event_name: event_name,
          env: env,
          source_app: source_app
        )
        Queue.new(name)
      end
    end

    def initialize(name)
      @client = Eventboss.configuration.sqs_client
      @name = name
    end

    def url
      @url ||= client.get_queue_url(queue_name: name).queue_url
    end

    def arn
      [
        'arn:aws:sqs',
        Eventboss.configuration.eventboss_region,
        Eventboss.configuration.eventboss_account_id,
        name
      ].join(':')
    end

    def <=>(another_queue)
      name <=> another_queue&.name
    end

    def eql?(another_queue)
      name == another_queue&.name
    end

    def hash
      name.hash
    end

    def to_s
      "<Eventboss::Queue: #{name}>"
    end

    private

    attr_reader :client
  end
end
