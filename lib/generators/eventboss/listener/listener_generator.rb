# frozen_string_literal: true

# Creates the Eventboss listener scaffold
#
# @example Invocation from terminal
#   rails generate eventboss:listener get_well air-helper
#
module Eventboss
  class ListenerGenerator < Rails::Generators::Base
    source_root File.expand_path(__dir__)

    argument :event_name, required: true
    argument :source_app, required: false

    desc 'Creates the Eventboss listener scaffold'
    def create_listener_scaffold
      template 'eventboss_listener.rb.erb', "app/listeners/#{ event_name }_listener.rb"
    end
  end
end
