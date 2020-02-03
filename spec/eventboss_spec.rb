require "spec_helper"

describe Eventboss do
  it "has a version number" do
    expect(Eventboss::VERSION).not_to be nil
  end

  describe '#launch' do
    it 'runs launch on runner' do
      expect(Eventboss::Runner).to receive(:launch)
      Eventboss.launch
    end
  end

  describe '.publish' do
    let(:sns_client) { instance_double(Eventboss::SnsClient, publish: :sns_response) }

    context 'in development mode' do
      before do
        ENV['EVENTBUS_DEVELOPMENT_MODE'] = 'true'
        allow(Eventboss.configuration).to receive(:sns_client).and_return(sns_client)
        allow(Eventboss.configuration).to receive(:eventboss_app_name).and_return('app_name1')
        allow(Eventboss::Topic).to receive(:build_name).with(event_name: 'lets-eat', source_app: 'app_name1').and_return('T')
        allow(sns_client).to receive(:create_topic).with(name: 'T')
      end

      it 'crates topic' do
        Eventboss.publisher('lets-eat')
        expect(sns_client).to have_received(:create_topic).with(name: 'T')
      end

      it 'uses Topic to build topic name' do
        Eventboss.publisher('lets-eat')
        expect(Eventboss::Topic).to have_received(:build_name).with(event_name: 'lets-eat', source_app: 'app_name1')
      end
    end
  end

  describe '#sender' do
    let(:event_name) { 'fake_event' }
    let(:destination_app) { 'fake_app' }
    let(:sqs_client) { double(publish: 'sqs_response') }
    let(:configuration) do
      Eventboss::Configuration.new.tap do |c|
        c.eventboss_app_name = 'app_name1'
        c.eventboss_region = 'dummy'
        c.sqs_client = sqs_client
      end
    end

    subject { described_class.sender(event_name, destination_app) }

    before do
      allow(described_class).to receive(:configuration) { configuration }
      allow(Eventboss.configuration).to receive(:development_mode?).and_return(false)
    end

    it 'calls Eventboss::Sender' do
      expect(Eventboss::Sender).to receive(:new).with(hash_including(:queue, :client))

      subject
    end

    context 'in development mode' do
      let(:queue) { double(name: 'Q') }

      before do
        allow(Eventboss).to receive(:env).and_return('EV')
        allow(Eventboss.configuration).to receive(:development_mode?).and_return(true)
        allow(Eventboss::Queue).to receive(:build).with(
          destination: 'dest-app',
          event_name: 'lets-eat',
          source_app: 'app_name1',
          env: 'EV'
        ).and_return(queue)
        allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q')
      end

      it 'crates queue with sqs client' do
        Eventboss.sender('lets-eat', 'dest-app')
        expect(sqs_client).to have_received(:create_queue).with(queue_name: 'Q')
      end

      it 'builds the Queue' do
        Eventboss.sender('lets-eat', 'dest-app')
        expect(Eventboss::Queue).to have_received(:build).with(hash_including(
          destination: 'dest-app',
          event_name: 'lets-eat',
          source_app: 'app_name1',
          env: 'EV'
        ))
      end
    end
  end
end
