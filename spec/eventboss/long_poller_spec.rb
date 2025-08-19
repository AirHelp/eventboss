require 'spec_helper'

describe Eventboss::LongPoller do
  subject do
    described_class.new(launcher, bus, client, queue, listener)
  end

  let(:launcher) { instance_double('Eventboss::Launcher', worker_stopped: true) }
  let(:bus) { [] }
  let(:client) { double('client') }
  let(:queue) { double('queue', name: 'name', url: 'url') }
  let(:listener) { double('listener') }
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
        .with(queue_url: 'url', max_number_of_messages: 10, wait_time_seconds: 10,
              attribute_names: ["SentTimestamp", "ApproximateReceiveCount"],
              message_attribute_names: ["sentry-trace", "baggage", "sentry_user"])

      subject.fetch_and_dispatch
    end

    context 'when queue is closed' do
      before do
        allow(bus).to receive(:<<).and_raise(ClosedQueueError)
      end

      it 'skip enqueuing the message' do
        subject.fetch_and_dispatch
        expect(bus.size).to be 0
      end
    end
  end
end
