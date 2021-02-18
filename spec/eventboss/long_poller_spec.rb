require 'spec_helper'

describe Eventboss::LongPoller do
  subject do
    described_class.new(launcher, bus, client, queue, listener)
  end

  let(:launcher) { instance_double('Eventboss::Launcher', worker_stopped: true) }
  let(:bus) { [] }
  let(:client) { double('client') }
  let(:queue) { double('queue', name: 'name', url: 'url') }
  let(:listener) do
    Class.new do
      include Eventboss::Listener

      def receive(payload)
      end
    end
  end
  let(:message) { double('message', message_id: 1) }

  before do
    allow(client).to receive(:receive_message) do
      OpenStruct.new(messages: [message])
    end
  end

  describe '#fetch_and_dispatch' do
    it 'adds to the bus' do
      subject.fetch_and_dispatch
      expect(bus.size).to be 1
    end

    it 'bus contains UnitOfWork' do
      subject.fetch_and_dispatch
      expect(bus).to include(an_instance_of(Eventboss::UnitOfWork))
    end

    it 'calls client with proper attributes' do
      expect(client).to receive(:receive_message)
        .with(queue_url: 'url', max_number_of_messages: 10, wait_time_seconds: 10)

      subject.fetch_and_dispatch
    end
  end
end
