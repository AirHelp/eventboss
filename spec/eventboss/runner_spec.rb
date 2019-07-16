require "spec_helper"

describe Eventboss::Runner do
  describe 'handling signals' do
    let(:default_sigterm_signal) { Signal.trap 'SIGTERM', 'SYSTEM_DEFAULT' }
    let(:queue) { double('queue', name: 'name', url: 'url') }
    let(:configuration) do
      Eventboss::Configuration.new.tap do |config|
        config.sqs_client = double
      end
    end

    # Put the Ruby default SIGTERM signal handler back in case it matters to other tests
    after { Signal.trap 'SIGTERM', default_sigterm_signal }

    it 'traps SIGTERM and handles it gracefully' do
      fork_pid = fork do
        expect(Eventboss::QueueListener).to receive(:list).and_return([queue])
        expect(Eventboss).to receive(:configuration).and_return(configuration)

        # Expect graceful stop
        expect_any_instance_of(Eventboss::Launcher).to receive(:stop)

        described_class.launch
      end

      # Waiting for the fork to call all the methods
      sleep 0.5

      # Sending the signal
      Process.kill 'SIGTERM', fork_pid

      # Verify is fork's exist status is 0
      fork_exit_status = Process.waitall.first.last.exitstatus
      expect(fork_exit_status).to eq 0
    end
  end
end
