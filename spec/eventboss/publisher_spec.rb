# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Eventboss::Publisher do
  before do
    ENV['EVENTBUS_DEVELOPMENT_MODE'] = 'false'
    allow(Eventboss).to receive(:env).and_return('ping')
    allow(Eventboss::Topic).to receive(:build_arn).with(event_name: 'event_name', source_app: 'app_name1')
      .and_return("arn:aws:sns:::eventboss-app_name1-event_name-ping")
  end

  describe '#publish' do
    subject { described_class.new('event_name', sns_client, configuration, opts).publish(payload) }

    let(:payload) { '{}' }
    let(:sns_client) { instance_double(Eventboss::SnsClient, publish: sns_response) }
    let(:sns_response) { double }
    let(:opts) { {} }
    let(:configuration) do
      Eventboss::Configuration.new.tap do |c|
        c.eventboss_app_name = 'app_name1'
      end
    end

    it 'publishes to sns with source app name by default' do
      expect(sns_client).to receive(:publish).with(
        topic_arn: "arn:aws:sns:::eventboss-app_name1-event_name-ping",
        message: "{}",
        message_attributes: {}
      )
      expect(subject).to eq(sns_response)
    end

    it 'uses Topic.build_arn' do
      subject
      expect(Eventboss::Topic).to have_received(:build_arn)
        .with(event_name: 'event_name', source_app: 'app_name1')
    end

    context 'when generic event' do
      let(:opts) { { generic: true } }

      before do
        allow(Eventboss::Topic).to receive(:build_arn).with(event_name: 'event_name', source_app: nil)
          .and_return("arn:aws:sns:::eventboss-event_name-ping")
      end

      it 'builds topic arn without source app name' do
        subject
        expect(Eventboss::Topic).to have_received(:build_arn).with(event_name: 'event_name', source_app: nil)
      end

      it 'publishes to sns without app name' do
        expect(sns_client).to receive(:publish).with(
          topic_arn: "arn:aws:sns:::eventboss-event_name-ping",
          message: "{}",
          message_attributes: {}
        )
        subject
      end
    end
  end
end
