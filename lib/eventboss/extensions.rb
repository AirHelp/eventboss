require 'eventboss/error_handlers/logger'
require 'eventboss/error_handlers/airbrake'
require 'eventboss/error_handlers/rollbar'
require 'eventboss/error_handlers/db_connection_drop_handler'
require 'eventboss/error_handlers/db_connection_not_established_handler'
require 'eventboss/error_handlers/non_existent_queue_handler'

# Load Sentry middleware if Sentry is available
begin
  require 'sentry-ruby'
  require 'eventboss/middleware/sentry_context'
rescue LoadError
  # Sentry not available, skip middleware
end
