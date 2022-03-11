# frozen_string_literal: true

require "spec_helper"

describe Eventboss::DevelopmentMode do
  describe 'development mode' do
    let(:queue1) { double(name: 'Q1', arn: 'Q: Q1', url: 'Q1.url') }
    let(:queue2) { double(name: 'Q2', arn: 'Q: Q2', url: 'Q2.url') }
    let(:listener1) { double(name: 'L1', options: { app_name: 'A1' }) }
    let(:listener2) { double(name: 'L2', options: { app_name: 'A2' }) }
    let(:queues) { { queue1 => listener1, queue2 => listener2 } }
    let(:topic1) { double(topic_arn: 'T1') }
    let(:topic2) { double(topic_arn: 'T2') }
    let(:sns_client) { double }
    let(:sqs_client) { double }

    before do
      allow(Eventboss.configuration).to receive(:development_mode?).and_return(true)
      allow(Eventboss.configuration).to receive(:sqs_client).and_return(sqs_client)
      allow(Eventboss.configuration).to receive(:sns_client).and_return(sns_client)
      allow(Eventboss::Topic).to receive(:build_name).with(app_name: 'A1').and_return('T1')
      allow(Eventboss::Topic).to receive(:build_name).with(app_name: 'A2').and_return('T2')
      allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q1')
      allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q1-deadletter')
      allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q2')
      allow(sqs_client).to receive(:create_queue).with(queue_name: 'Q2-deadletter')
      allow(sns_client).to receive(:create_topic).with(name: 'T1').and_return(topic1)
      allow(sns_client).to receive(:create_topic).with(name: 'T2').and_return(topic2)
      allow(sns_client).to receive(:create_subscription)
        .with(topic_arn: 'T1', queue_arn: 'Q: Q1').and_return(topic1)
      allow(sns_client).to receive(:create_subscription)
        .with(topic_arn: 'T2', queue_arn: 'Q: Q2').and_return(topic2)
      allow(sqs_client).to receive(:set_queue_attributes).with(queue_url: 'Q1.url', attributes: hash_including(:Policy))
      allow(sqs_client).to receive(:set_queue_attributes).with(queue_url: 'Q2.url', attributes: hash_including(:Policy))
    end

    it 'creates required topics' do
      described_class.setup_infrastructure(queues)

      expect(sns_client).to have_received(:create_topic).with(name: 'T1')
      expect(sns_client).to have_received(:create_topic).with(name: 'T2')
    end

    it 'creates queues' do
      described_class.setup_infrastructure(queues)

      expect(sqs_client).to have_received(:create_queue).with(queue_name: 'Q1')
      expect(sqs_client).to have_received(:create_queue).with(queue_name: 'Q2')
      expect(sqs_client).to have_received(:set_queue_attributes).with(queue_url: 'Q1.url', attributes: hash_including(:Policy))
    end

    it 'subscribes topics to queues' do
      described_class.setup_infrastructure(queues)

      expect(sns_client).to have_received(:create_subscription).with(queue_arn: 'Q: Q1', topic_arn: 'T1')
      expect(sns_client).to have_received(:create_subscription).with(queue_arn: 'Q: Q2', topic_arn: 'T2')
    end
  end
end
