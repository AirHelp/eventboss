require 'spec_helper'

describe Eventboss::Worker do
  subject do
    described_class.new(launcher, queue, bus)
  end

  Work = Struct.new(:finished) do
    def run(*)
      self.finished = true
    end
  end

  FailedWork = Struct.new(:exception) do
    def run(*)
      raise exception
    end
  end

  let(:launcher) { instance_double('Eventboss::Launcher', worker_stopped: true) }
  let(:queue) { double('queue', url: 'url') }
  let(:bus) { [] }

  context 'when work has no errors' do
    let(:work) { Work.new }

    before { bus << work }

    it 'runs the job' do
      subject.run
      expect(work.finished).to be true
    end

    it 'stops the launcher' do
      expect(launcher).to receive(:worker_stopped).with(subject)
      subject.run
    end
  end

  context 'when work has errors' do
    let(:work) { FailedWork.new(error) }

    before { bus << work }

    context 'with exception' do
      let(:error) { Exception }

      it 'handles the error' do
        expect { subject.run }.not_to raise_error
      end

      it 'restarts the worker' do
        expect(launcher).to receive(:worker_stopped).with(subject, restart: true)
        subject.run
      end
    end

    context 'on shutdown' do
      let(:error) { Eventboss::Shutdown }

      it 'handles the error' do
        expect { subject.run }.not_to raise_error
      end

      it 'stops the worker' do
        expect(launcher).to receive(:worker_stopped).with(subject)
        subject.run
      end
    end
  end
end
