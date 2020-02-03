# frozen_string_literal: true

require "spec_helper"

describe Eventboss::Runner do
  describe 'handling signals' do
    let(:default_sigterm_signal) { Signal.trap 'SIGTERM', 'SYSTEM_DEFAULT' }
    let(:queue) { double('queue', name: 'name', url: 'url') }
    let(:client_mock) { double }
    let(:configuration) do
      Eventboss::Configuration.new.tap do |config|
        config.sqs_client = client_mock
        config.logger = Logger.new(IO::NULL)
      end
    end
    let(:queue1) { double(name: 'Q1', arn: 'Q: Q1') }
    let(:queue2) { double(name: 'Q2', arn: 'Q: Q2') }
    let(:listener1) { double(name: 'L1', options: {}) }
    let(:listener2) { double(name: 'L2', options: {}) }
    let(:queues) { { queue1 => listener1, queue2 => listener2 } }
    let(:topic) { double(topic_arn: 'T1') }
    let(:launcher) { instance_double(Eventboss::Launcher) }
    let(:sns_client) { double }
    let(:sqs_client) { double }

    before do
      ENV['EVENTBUS_DEVELOPMENT_MODE'] = 'false'
      allow(Eventboss.configuration).to receive(:sqs_client).and_return(sqs_client)
      allow(Eventboss.configuration).to receive(:sns_client).and_return(sns_client)
      allow(Eventboss::QueueListener).to receive(:select).and_return(queues)
      allow(Eventboss::Instrumentation).to receive(:add).with(queues)
      allow(Eventboss::Launcher).to receive(:new).and_return(launcher)
      allow(Eventboss::Topic).to receive(:build_name).and_return('T')
      allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q1')
      allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q2')
      allow(sns_client).to receive(:create_topic).with(name: 'T').and_return(topic)
      allow(sns_client).to receive(:create_subscription)
        .with(topic_arn: 'T1', queue_arn: 'Q: Q1').and_return(topic)
      allow(sns_client).to receive(:create_subscription)
        .with(topic_arn: 'T1', queue_arn: 'Q: Q2').and_return(topic)
      allow(launcher).to receive(:start).and_raise(Interrupt)
      allow(launcher).to receive(:stop)
      allow(Eventboss::DevelopmentMode).to receive(:setup_infrastructure).with(queues)
    end

    # Put the Ruby default SIGTERM signal handler back in case it matters to other tests
    after { Signal.trap 'SIGTERM', default_sigterm_signal }

    it 'traps SIGTERM and handles it gracefully' do
      fork_pid = fork do
        expect(Eventboss::QueueListener).to receive(:select).and_return(queues)
        expect(client_mock).to receive(:receive_message).and_return(double(messages: [1, 2, 3]))
        expect(Eventboss).to receive(:configuration).and_return(configuration)

        # Expect graceful stop
        expect_any_instance_of(Eventboss::Launcher).to receive(:stop)

        described_class.launch
      end

      # Waiting for the fork to call all the methods
      sleep 0.5

      # Sending the signal
      Process.kill 'SIGTERM', fork_pid

      # Verify if fork's exist status is 0
      fork_exit_status = Process.waitall.first.last.exitstatus
      expect(fork_exit_status).to eq 0
    end

    context 'development mode' do
      it 'is disabled by default' do
        fork { described_class.launch }

        expect(Eventboss::DevelopmentMode).not_to have_received(:setup_infrastructure).with(queues)
      end

      it "it is creating infrastructure" do
        allow(Eventboss.configuration).to receive(:development_mode?).and_return(true)

        fork do
          described_class.launch
          expect(Eventboss::DevelopmentMode).to have_received(:setup_infrastructure).with(queues)
        end
      end
    end
  end
end
