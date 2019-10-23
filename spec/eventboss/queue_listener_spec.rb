require "spec_helper"

describe Eventboss::QueueListener do
  before do
    Eventboss.configure do |config|
      config.sqs_client = double('client')
      config.eventboss_app_name = 'app1'
      config.listeners = {}
    end
    ENV['EVENTBUS_ENV'] = 'staging'
  end

  before do
    stub_const 'Eventboss::Listener::ACTIVE_LISTENERS', {}
    stub_const 'Listener1', Class.new
    Listener1.class_eval do
      include Eventboss::Listener
      eventboss_options source_app: 'destapp1', event_name: 'transaction_created'
    end

    stub_const 'Listener2', Class.new
    Listener2.class_eval do
      include Eventboss::Listener
      eventboss_options source_app: 'destapp2', event_name: 'file_uploaded'
    end

    stub_const 'Listener3', Class.new
    Listener3.class_eval do
      include Eventboss::Listener
      eventboss_options source_app: 'destapp3', event_name: 'file_destroyed'
    end
  end

  describe '.select' do
    context 'with include arg' do
      it 'returns only included listeners' do
        queue_listeners = Eventboss::QueueListener.select(include: ['Listener1'])
        expect(queue_listeners[Eventboss::Queue.new("app1-eventboss-destapp1-transaction_created-#{Eventboss.env}")]).to eq(Listener1)
        expect(queue_listeners.count).to eq 1
      end
    end

    context 'with exclude arg' do
      it 'returns all not excluded listeners' do
        queue_listeners = Eventboss::QueueListener.select(exclude: ['Listener3'])
        expect(queue_listeners[Eventboss::Queue.new("app1-eventboss-destapp1-transaction_created-#{Eventboss.env}")]).to eq(Listener1)
        expect(queue_listeners[Eventboss::Queue.new("app1-eventboss-destapp2-file_uploaded-#{Eventboss.env}")]).to eq(Listener2)
        expect(queue_listeners.count).to eq 2
      end
    end

    context 'with include and exclude args' do
      it 'returns only included (not excluded) listeners' do
        queue_listeners = Eventboss::QueueListener.select(
          exclude: %w[Listener1 Listener2],
          include: %w[Listener2 Listener3]
        )
        expect(queue_listeners[Eventboss::Queue.new("app1-eventboss-destapp3-file_destroyed-#{Eventboss.env}")]).to eq(Listener3)
        expect(queue_listeners.count).to eq 1
      end
    end
  end
end
