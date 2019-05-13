require 'spec_helper'

RSpec.describe Eventboss::Configuration do
  let(:configuration) { described_class.new }

  describe 'accessors with lazy evaluated defaults' do
    subject { configuration }
    it 'always returns explicitly set value' do
      expect(subject.raise_on_missing_configuration).to eq(false)
      subject.raise_on_missing_configuration = nil
      expect(subject.raise_on_missing_configuration).to eq(nil)
      subject.raise_on_missing_configuration = true
      expect(subject.raise_on_missing_configuration).to eq(true)
    end

    it 'caches evaluated default' do
      expect(subject.sns_client.object_id).to eq(subject.sns_client.object_id)
    end
  end

  describe '#concurrency' do
    subject { configuration.concurrency }
    context 'when not set' do
      it 'returns default concurrency of 25' do
        expect(subject).to eq(25)
      end
    end

    context 'when in ENV' do
      before { ENV['EVENTBUS_CONCURRENCY'] = '10' }

      it 'is taken from ENV' do
        expect(subject).to eq(10)
      end
    end
  end
end
