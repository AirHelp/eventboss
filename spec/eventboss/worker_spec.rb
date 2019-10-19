require 'spec_helper'

describe Eventboss::Worker do
  subject do
    described_class.new(launcher, queue, bus, restart_on: [StandardError])
  end

  let(:launcher) { instance_double('Eventboss::Launcher', worker_stopped: true) }
  let(:queue) { double('queue', url: 'url') }
  let(:bus) { [] }

  let(:work) do
    instance_double('UnitOfWork', queue: nil, listener: nil, message: nil)
  end

  context 'when work has no errors' do
    before { bus << work }

    it 'runs the job' do
      expect(work).to receive(:run)
      subject.run
    end

    it 'stops the launcher' do
      expect(work).to receive(:run)
      expect(launcher).to receive(:worker_stopped).with(subject)
      subject.run
    end
  end

  context 'when work has errors' do
    before { bus << work }

    context 'with exception' do
      subject do
        described_class.new(launcher, queue, bus, restart_on: [Exception])
      end

      let(:error) { Exception }

      it 'handles the error' do
        expect(work).to receive(:run) { raise error }
        expect { subject.run }.not_to raise_error
      end

      it 'restarts the worker' do
        expect(work).to receive(:run) { raise error }
        expect(launcher).to receive(:worker_stopped).with(subject, restart: true)
        subject.run
      end
    end

    context 'on shutdown' do
      let(:error) { Eventboss::Shutdown }

      it 'handles the error' do
        expect(work).to receive(:run) { raise error }
        expect { subject.run }.not_to raise_error
      end

      it 'stops the worker' do
        expect(work).to receive(:run) { raise error }
        expect(launcher).to receive(:worker_stopped).with(subject)
        subject.run
      end
    end
  end
end
