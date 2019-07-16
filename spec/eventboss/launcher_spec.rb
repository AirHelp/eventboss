require "spec_helper"

describe Eventboss::Launcher do
  let(:sqs_client) { instance_double(Aws::SQS::Client, send_message_batch: double) }
  let(:queue) { double('queue', name: 'name', url: 'url') }

  subject { described_class.new([queue], sqs_client) }

  before do
    allow(sqs_client).to receive(:receive_message) { OpenStruct.new(messages: []) }
  end

  describe 'handling signals' do
    let(:default_sigterm_signal) { Signal.trap 'SIGTERM', 'SYSTEM_DEFAULT' }

    # Put the Ruby default SIGTERM signal handler back in case it matters to other tests
    after { Signal.trap 'SIGTERM', default_sigterm_signal }

    it 'traps SIGTERM and handles it gracefully' do
      subject.start

      expect(subject).to receive(:stop)

      # Send the signal
      Process.kill 'SIGTERM', 0
    end
  end
end
