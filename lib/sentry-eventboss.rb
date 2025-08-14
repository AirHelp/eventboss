# frozen_string_literal: true

require "eventboss"
require "sentry-ruby"
require "sentry/integrable"
require "sentry/eventboss/version"
require "sentry/eventboss/configuration"
require "sentry/eventboss/error_handler"
require "sentry/eventboss/middleware"
require "sentry/eventboss/client_middleware"

module Sentry
  module Eventboss
    extend Sentry::Integrable

    register_integration name: "eventboss", version: Sentry::Eventboss::VERSION

    def self.capture_exception(exception, contexts: {}, hint: {})
      Sentry.capture_exception(exception, contexts: contexts, hint: hint)
    end

    if defined?(::Rails::Railtie)
      class Railtie < ::Rails::Railtie
        config.after_initialize do
          next unless Sentry.initialized?

          # Auto-configure Eventboss when Rails is loaded
          auto_configure_eventboss
        end
      end
    end

    # Auto-configure when Eventboss is available
    def self.auto_configure_eventboss
      return unless defined?(::Eventboss) && Sentry.initialized?

      # Add Sentry error handler if not already present
      error_handlers = ::Eventboss.configuration.error_handlers
      unless error_handlers.any? { |handler| handler.is_a?(Sentry::Eventboss::ErrorHandler) }
        error_handlers << Sentry::Eventboss::ErrorHandler.new
      end

      # Add middleware if it's not already present
      middleware_chain = ::Eventboss.configuration.server_middleware
      unless middleware_chain.entries.any? { |entry| entry.klass == Sentry::Eventboss::Middleware }
        middleware_chain.add Sentry::Eventboss::Middleware
      end
    end
  end
end

# Auto-configure if Eventboss is already loaded
if defined?(::Eventboss)
  Sentry::Eventboss.auto_configure_eventboss
end
