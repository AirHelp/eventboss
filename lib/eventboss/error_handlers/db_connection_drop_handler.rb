# frozen_string_literal: true

module Eventboss
  module ErrorHandlers
    class DbConnectionDropHandler
      def call(exception, _context = {})
        return unless exception.is_a?(::ActiveRecord::StatementInvalid)

        if Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new('8.0.0')
          ::ActiveRecord::Base.clear_active_connections!
        else
          ::ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    end
  end
end
