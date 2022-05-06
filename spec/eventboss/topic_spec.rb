# frozen_string_literal: true

require "spec_helper"

describe Eventboss::Topic do
  describe '.build_arn' do
    subject { described_class.build_arn(event_name: 'summer_party', source_app: 'jigger') }

    before do
      allow(Eventboss.configuration).to receive(:eventboss_region).and_return('eu-west-1')
      allow(Eventboss.configuration).to receive(:eventboss_account_id).and_return(123098)
      allow(Eventboss.configuration).to receive(:sns_sqs_name_infix).and_return('eventbus')
      allow(Eventboss).to receive(:env).and_return('development')
    end

    it "contains the region, account id, infix, application name, event name and environment" do
      expect(subject).to eql('arn:aws:sns:eu-west-1:123098:eventbus-jigger-summer_party-development')
    end

    context 'when source application not passed' do
      subject { described_class.build_arn(event_name: 'summer_party') }

      it "doesn't contain application name" do
        expect(subject).to eql('arn:aws:sns:eu-west-1:123098:eventbus-summer_party-development')
      end

    end
  end

  describe '.build_name' do
    subject { described_class.build_name(event_name: 'summer_party', source_app: 'jigger') }

    before do
      allow(Eventboss.configuration).to receive(:sns_sqs_name_infix).and_return('eventbus')
      allow(Eventboss).to receive(:env).and_return('development')
    end

    it "contains the infix, application name, event name and environment" do
      expect(subject).to eql('eventbus-jigger-summer_party-development')
    end

    context 'when source application not passed' do
      subject { described_class.build_name(event_name: 'summer_party') }

      it "doesn't contain application name" do
        expect(subject).to eql('eventbus-summer_party-development')
      end
    end
  end
end
