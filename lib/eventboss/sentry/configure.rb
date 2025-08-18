# frozen_string_literal: true

require_relative 'integration'

# Auto configure eventboss to use sentry

Eventboss.configure do |config|
  config.server_middleware.add Eventboss::Sentry::ServerMiddleware
  config.error_handlers << Eventboss::Sentry::ErrorHandler.new
end

