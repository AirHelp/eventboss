require 'sentry-ruby'
require 'sentry/integrable'
require_relative 'error_handler'
require_relative 'context'
require_relative 'server_middleware'

module Eventboss
  module Sentry
    class Integration
      extend ::Sentry::Integrable

      register_integration name: "eventboss", version: Eventboss::VERSION
    end
  end
end
