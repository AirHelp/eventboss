require 'spec_helper'

describe Sentry::Eventboss::Configuration do
  subject { described_class.new }

  describe 'default values' do
    it 'has sensible defaults' do
      expect(subject.report_after_job_retries).to eq(false)
      expect(subject.capture_message_body).to eq(false)
      expect(subject.capture_message_headers).to eq(true)
      expect(subject.max_message_body_size).to eq(4096)
      expect(subject.excluded_processors).to eq([])
      expect(subject.performance_monitoring).to eq(false)
      expect(subject.propagate_traces).to eq(true)
      expect(subject.capture_processor_context).to eq(true)
    end
  end

  describe '#excluded_processor?' do
    before do
      subject.excluded_processors = ['ExcludedProcessor', 'AnotherExcludedProcessor']
    end

    context 'when given a class' do
      let(:excluded_class) { double('class', to_s: 'ExcludedProcessor') }
      let(:included_class) { double('class', to_s: 'IncludedProcessor') }

      it 'returns true for excluded processor classes' do
        expect(subject.excluded_processor?(excluded_class)).to eq(true)
      end

      it 'returns false for included processor classes' do
        expect(subject.excluded_processor?(included_class)).to eq(false)
      end
    end

    context 'when given an instance' do
      let(:excluded_instance) { double('instance', class: double(to_s: 'ExcludedProcessor')) }
      let(:included_instance) { double('instance', class: double(to_s: 'IncludedProcessor')) }

      it 'returns true for instances of excluded processor classes' do
        expect(subject.excluded_processor?(excluded_instance)).to eq(true)
      end

      it 'returns false for instances of included processor classes' do
        expect(subject.excluded_processor?(included_instance)).to eq(false)
      end
    end
  end

  describe 'configuration options' do
    it 'allows setting report_after_job_retries' do
      subject.report_after_job_retries = true
      expect(subject.report_after_job_retries).to eq(true)
    end

    it 'allows setting capture_message_body' do
      subject.capture_message_body = true
      expect(subject.capture_message_body).to eq(true)
    end

    it 'allows setting capture_message_headers' do
      subject.capture_message_headers = false
      expect(subject.capture_message_headers).to eq(false)
    end

    it 'allows setting max_message_body_size' do
      subject.max_message_body_size = 8192
      expect(subject.max_message_body_size).to eq(8192)
    end

    it 'allows setting excluded_processors' do
      processors = ['NoisyProcessor', 'TestProcessor']
      subject.excluded_processors = processors
      expect(subject.excluded_processors).to eq(processors)
    end

    it 'allows setting performance_monitoring' do
      subject.performance_monitoring = true
      expect(subject.performance_monitoring).to eq(true)
    end

    it 'allows setting propagate_traces' do
      subject.propagate_traces = false
      expect(subject.propagate_traces).to eq(false)
    end

    it 'allows setting capture_processor_context' do
      subject.capture_processor_context = false
      expect(subject.capture_processor_context).to eq(false)
    end
  end
end
