module Eventboss
  class Queue
    include Comparable
    attr_reader :name

    def self.build_name(source:, destination:, event:, env:, generic:)
      source =
        if generic
          ''
        else
          "-#{source}"
        end

      "#{destination}-eventboss#{source}-#{event}-#{env}"
    end

    def initialize(name, configuration = Eventboss.configuration)
      @client = configuration.sqs_client
      @name = name
    end

    def url
      @url ||= client.get_queue_url(queue_name: name).queue_url
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

    private

    attr_reader :client
  end
end
