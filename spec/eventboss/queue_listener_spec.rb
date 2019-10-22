require "spec_helper"

describe Eventboss::QueueListener do
  before do
    Eventboss.configure do |config|
      config.sqs_client = double('client')
      config.eventboss_app_name = 'app1'
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

  context '#list' do
    it 'builds a map of queue to listener' do
      expect(Eventboss::QueueListener.list[Eventboss::Queue.new("app1-eventboss-destapp1-transaction_created-#{Eventboss.env}")]).to eq(Listener1)
      expect(Eventboss::QueueListener.list[Eventboss::Queue.new("app1-eventboss-destapp2-file_uploaded-#{Eventboss.env}")]).to eq(Listener2)
    end
  end

  describe '.list_active' do
    context 'with include arg' do
      before { Eventboss.configuration.listeners = { include: ['Listener1'] } }

      it 'returns only included listeners' do
        expect(Eventboss::QueueListener.list_active[Eventboss::Queue.new("app1-eventboss-destapp1-transaction_created-#{Eventboss.env}")]).to eq(Listener1)
        expect(Eventboss::QueueListener.list_active.count).to eq 1
      end
    end

    context 'with exclude arg' do
      before { Eventboss.configuration.listeners = { exclude: ['Listener3'] } }

      it 'returns all not excluded listeners' do
        expect(Eventboss::QueueListener.list_active[Eventboss::Queue.new("app1-eventboss-destapp1-transaction_created-#{Eventboss.env}")]).to eq(Listener1)
        expect(Eventboss::QueueListener.list[Eventboss::Queue.new("app1-eventboss-destapp2-file_uploaded-#{Eventboss.env}")]).to eq(Listener2)
        p Eventboss::QueueListener.list_active
        expect(Eventboss::QueueListener.list_active.count).to eq 2
      end
    end

    context 'with include and exclude args' do
      before { Eventboss.configuration.listeners = { exclude: ['Listener1', 'Listener2'], include: ['Listener2', 'Listener3'] } }

      it 'returns only included (not excluded) listeners' do
        expect(Eventboss::QueueListener.list[Eventboss::Queue.new("app1-eventboss-destapp3-file_destroyed-#{Eventboss.env}")]).to eq(Listener3)
        expect(Eventboss::QueueListener.list_active.count).to eq 1
      end
    end
  end
end
