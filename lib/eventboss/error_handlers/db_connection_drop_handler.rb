module Eventboss
  module ErrorHandlers
    class DbConnectionDropHandler
      def call(exception, context = {})
        if exception.class == ActiveRecord::StatementInvalid
          ActiveRecord::Base.clear_active_connections!
        end
      end
    end
  end
end

