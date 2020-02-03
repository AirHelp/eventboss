# frozen_string_literal: true

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
        expect(Eventboss.logger).to receive(:info).and_call_original
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

  describe '#create_topic' do
    subject { described_class.new(configuration).create_topic(name: '+') }

    context 'for configured sns' do
      let(:configuration) do
        Eventboss::Configuration.new.tap do |config|
          config.eventboss_region = 'test'
          config.eventboss_account_id = 'test'
          config.eventboss_app_name = 'test'
        end
      end
      let(:sns_client) { instance_double(Aws::SNS::Client) }

      before do
        allow(Aws::SNS::Client).to receive(:new).and_return(sns_client)
        allow(sns_client).to receive(:create_topic)
      end

      it 'creates new topic with a given name with sns client' do
        subject
        expect(sns_client).to have_received(:create_topic).with(name: '+')
      end
    end
  end

  describe '#create_subscription' do
    subject do
      described_class.new(configuration).create_subscription(topic_arn: 'TA?', queue_arn: 'QA?')
    end

    context 'for configured sns' do
      let(:configuration) do
        Eventboss::Configuration.new.tap do |config|
          config.eventboss_region = 'test'
          config.eventboss_account_id = 'test'
          config.eventboss_app_name = 'test'
        end
      end
      let(:sns_client) { instance_double(Aws::SNS::Client) }
      let(:subscription) { double(subscription_arn: 'S?') }

      before do
        allow(Aws::SNS::Client).to receive(:new).and_return(sns_client)
        allow(sns_client).to receive(:subscribe).and_return(subscription)
        allow(sns_client).to receive(:set_subscription_attributes)
      end

      it 'creates subscription for topic and queue' do
        subject
        expect(sns_client).to have_received(:subscribe)
          .with(endpoint: 'QA?', topic_arn: 'TA?', protocol: 'sqs')
      end

      it 'sets subscription RawMessageDelivery attribute' do
        subject
        expect(sns_client).to have_received(:set_subscription_attributes).with(
          subscription_arn: subscription.subscription_arn,
          attribute_name: 'RawMessageDelivery',
          attribute_value: 'true'
        )
      end
    end
  end
end
