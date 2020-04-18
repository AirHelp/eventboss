module Eventboss
  module Middleware
    class Chain
      attr_reader :entries

      def initialize
        @entries = []
      end

      def add(klass, options = {})
        @entries << Entry.new(klass, options)
      end

      def invoke(*args)
        chain = @entries.map(&:build).reverse!

        invoke_lambda = lambda do
          if (mid = chain.pop)
            mid.call(*args, &invoke_lambda)
          else
            yield
          end
        end
        invoke_lambda.call
      end

      def clear
        @entries.clear
      end
    end

    class Base
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def call
        raise 'Not implemented'
      end
    end

    class Entry
      attr_reader :klass, :options

      def initialize(klass, options)
        @klass = klass
        @options = options
      end

      def build
        @klass.new(options)
      end
    end
  end
end
