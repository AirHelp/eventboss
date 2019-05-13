require 'spec_helper'

describe Eventboss::UnitOfWork do
  class Listener
    def jid; end

    def receive; end
  end

  subject do
    described_class.new(queue, Listener, message)
  end

  let(:queue) { double('queue', url: 'url') }
  let(:client) { double('client') }
  let(:message) do
    double('message', message_id: 'id', body: '{}', receipt_handle: 'handle')
  end

  context 'with sucessful job' do
    it 'runs the job' do
      expect_any_instance_of(Listener).to receive(:receive).and_return(true)
      expect(client)
        .to receive(:delete_message).with(queue_url: 'url', receipt_handle: 'handle')

      subject.run(client)
    end
  end

  context 'with failed job' do
    it 'does not cleanup message' do
      expect_any_instance_of(Listener).to receive(:receive).and_raise(RuntimeError)
      expect(client).not_to receive(:delete_message)

      subject.run(client)
    end
  end

  context 'with invalid JSON payload' do
    let(:message) do
      double('message', message_id: 'id', body: '.')
    end

    it 'does not run the job' do
      expect_any_instance_of(Listener).not_to receive(:receive)
      expect(client).not_to receive(:delete_message)

      subject.run(client)
    end
  end
end
