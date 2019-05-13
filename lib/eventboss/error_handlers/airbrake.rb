module Eventboss
  module ErrorHandlers
    class Airbrake
      def call(exception, context = {})
        ::Airbrake.notify(exception) do |notice|
          notice[:context][:component] = 'eventboss'
          notice[:context][:action] = context[:processor].class.to_s if context[:processor]
          notice[:context].merge!(context)
        end
      end
    end
  end
end
