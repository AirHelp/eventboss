module Eventboss
  module ErrorHandlers
    class DbConnectionNotEstablishedHandler
      def call(exception, _context = {})
        if exception.class == ::ActiveRecord::ConnectionNotEstablished
          ::ActiveRecord::Base.connection.reconnect!
        end
      end
    end
  end
end
