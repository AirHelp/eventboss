# frozen_string_literal: true

require "spec_helper"

describe Eventboss::Topic do
  describe '.build_arn' do
    subject { described_class.build_arn(event_name: 'J', source_app: 'CH') }

    before do
      allow(Eventboss.configuration).to receive(:eventboss_region)
      allow(Eventboss.configuration).to receive(:eventboss_account_id)
      allow(Eventboss::Topic).to receive(:build_name)
    end

    it 'includes aws arn part' do
      expect(subject).to include('arn:aws:sns')
    end

    it 'uses eventboss region' do
      subject
      expect(Eventboss.configuration).to have_received(:eventboss_region)
    end

    it 'uses eventboss account id' do
      subject
      expect(Eventboss.configuration).to have_received(:eventboss_account_id)
    end

    it 'passes params to .build_name' do
      subject
      expect(Eventboss::Topic).to have_received(:build_name)
        .with(event_name: 'J', source_app: 'CH')
    end

    context 'when source app not given' do
      subject { described_class.build_arn(event_name: 'J') }

      it 'is passed as nil' do
        subject
        expect(Eventboss::Topic).to have_received(:build_name)
          .with(event_name: 'J', source_app: nil)
      end
    end
  end

  describe '.build_name' do
    subject { described_class.build_name(event_name: 'J', source_app: 'CH') }

    before do
      allow(Eventboss).to receive(:env)
      allow(Eventboss.configuration).to receive(:sns_sqs_name_infix)
    end

    it 'includes required params' do
      expect(subject).to include('CH-J')
    end

    it 'uses eventboss env' do
      subject
      expect(Eventboss).to have_received(:env)
    end

    it 'uses eventboss sns_sqs_name_infix' do
      subject
      expect(Eventboss.configuration).to have_received(:sns_sqs_name_infix)
    end

    context 'when source app not passed' do
      subject { described_class.build_name(event_name: 'J') }

      before do
        allow(Eventboss.configuration).to receive(:sns_sqs_name_infix)
          .and_return('infix')
      end

      it 'event name is right after the infix' do
        expect(subject).to include('infix-J')
      end
    end
  end
end
