require 'spec_helper'

RSpec.describe Eventboss::Publisher do
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
        topic_arn: "arn:aws:sns:::eventboss-app_name1-event_name-#{Eventboss.env}",
        message: "{}"
      )
      expect(subject).to eq(sns_response)
    end

    context 'when generic event' do
      let(:opts) { { generic: true } }

      it 'publishes to sns without app name' do
        expect(sns_client).to receive(:publish).with(
          topic_arn: "arn:aws:sns:::eventboss-event_name-#{Eventboss.env}",
          message: "{}"
        )
        expect(subject).to eq(sns_response)
      end
    end
  end
end
