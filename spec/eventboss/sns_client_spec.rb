require 'spec_helper'

RSpec.describe Eventboss::SnsClient do
  describe '#publish' do
    subject { described_class.new(configuration).publish(payload) }
    let(:payload) { '{}' }

    context 'for not configured sns' do
      let(:configuration) do
        Eventboss::Configuration.new.tap do |config|
          config.eventboss_region = nil
          config.eventboss_account_id = nil
          config.eventboss_app_name = nil
        end
      end

      it 'logs info' do
        expect(Eventboss::Logger).to receive(:info).and_call_original
        subject
      end

      context 'with raise_on_missing_configuration config' do
        let(:configuration) do
          Eventboss::Configuration.new.tap do |config|
            config.raise_on_missing_configuration = true
            config.eventboss_region = nil
            config.eventboss_account_id = nil
            config.eventboss_app_name = nil
          end
        end

        it 'raises error' do
          expect { subject }.to raise_error(Eventboss::NotConfigured)
        end
      end
    end

    context 'for configured sns' do
      let(:configuration) do
        Eventboss::Configuration.new.tap do |config|
          config.eventboss_region = 'test'
          config.eventboss_account_id = 'test'
          config.eventboss_app_name = 'test'
        end
      end

      before do
        expect(Aws::SNS::Client).to receive(:new).and_return(instance_double(Aws::SNS::Client, publish: sns_response))
      end
      let(:sns_response) { double }

      it 'publishes to sns' do
        expect(subject).to eq(sns_response)
      end
    end
  end
end
