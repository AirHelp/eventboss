require 'spec_helper'

RSpec.describe Eventboss::Sender do
  describe '#send_batch' do
    let(:sender) { described_class.new(queue: queue, client: sqs_client) }
    let(:sqs_client) do
      instance_double(Aws::SQS::Client, send_message_batch: double)
    end
    let(:queue_url) { 'sample_queue_url' }
    let(:queue) { instance_double(Eventboss::Queue, url: queue_url) }
    let(:payload) do
      [
        { key: 'val' }
      ]
    end

    subject { sender.send_batch(payload) }

    it 'sends messages to given queue' do
      expect(sqs_client).to receive(:send_message_batch).with(
        hash_including(
          queue_url: queue_url
        )
      )

      subject
    end

    it 'sets id for each message' do
      expect(sqs_client).to receive(:send_message_batch).with(
        hash_including(
          entries: array_including(hash_including(:id))
        )
      )

      subject
    end

    it 'sets message data under message_body key' do
      expect(sqs_client).to receive(:send_message_batch).with(
        hash_including(
          entries: array_including(hash_including(message_body: payload.first.to_json))
        )
      )

      subject
    end
  end
end
