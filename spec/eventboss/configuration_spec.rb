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

    context 'when in ENV' do
      after { ENV['EVENTBUS_RAISE_ON_MISSING_CONFIGURATION'] = nil }

      context 'when false' do
        %w(false False FALSE not_know).each do |falsey_value|
          before { ENV['EVENTBUS_RAISE_ON_MISSING_CONFIGURATION'] = falsey_value }

          it "returns false for #{falsey_value}" do
            expect(subject.raise_on_missing_configuration).to eq(false)
          end
        end
      end

      context 'when true' do
        %w(true TRUE True).each do |truthy_value|
          before { ENV['EVENTBUS_RAISE_ON_MISSING_CONFIGURATION'] = truthy_value }

          it "returns true for #{truthy_value}" do
            expect(subject.raise_on_missing_configuration).to eq(true)
          end
        end
      end
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

    context 'when set through configuration' do
      context 'when set a correct string value' do
        before { configuration.concurrency = '11' }

        it 'returns int value' do
          expect(subject).to eq(11)
        end
      end

      context 'when set an incorrect string value' do
        subject { configuration.concurrency = 'incorrect value' }

        it 'raises an error' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'when set an int value' do
        before { configuration.concurrency = 11 }

        it { expect(subject).to eq(11) }
      end
    end
  end
end
