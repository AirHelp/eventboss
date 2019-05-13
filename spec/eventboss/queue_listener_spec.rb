require "spec_helper"

describe Eventboss::QueueListener do
  before do
    Eventboss.configure do |config|
      config.sqs_client = double('client')
      config.eventboss_app_name = 'app1'
    end
    ENV['EVENTBUS_ENV'] = 'staging'
  end

  context '#list' do
    it 'builds a map of queue to listener' do
      class Listener1
        include Eventboss::Listener
        eventboss_options source_app: 'destapp1', event_name: 'transaction_created'
      end
      class Listener2
        include Eventboss::Listener
        eventboss_options source_app: 'destapp2', event_name: 'file_uploaded'
      end
      expect(Eventboss::QueueListener.list[Eventboss::Queue.new("app1-eventboss-destapp1-transaction_created-#{Eventboss.env}")]).to eq(Listener1)
      expect(Eventboss::QueueListener.list[Eventboss::Queue.new("app1-eventboss-destapp2-file_uploaded-#{Eventboss.env}")]).to eq(Listener2)
    end
  end
end
