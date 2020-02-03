require "spec_helper"

describe Eventboss::Fetcher do
  let(:queue) { instance_double(Eventboss::Queue, url: 'url') }
  let(:client_mock) { double('client_mock', get_queue_url: double(queue_url: 'url')) }
  let(:configuration) do
    Eventboss::Configuration.new.tap do |config|
      config.sqs_client = client_mock
    end
  end

  subject { described_class.new(configuration) }

  context '#FETCH_LIMIT' do
    it 's set to 10' do
      expect(Eventboss::Fetcher::FETCH_LIMIT).to eq(10)
    end
  end

  context '#fetch' do
    context 'when limit higher that 10' do
      it 'calls receive client with max no msg eq 10' do
        expect(client_mock).to receive(:receive_message).with(queue_url: 'url', max_number_of_messages: 10).and_return(double(messages: [1, 2, 3]))
        expect(subject.fetch(queue, 20)).to eq([1, 2, 3])
      end
    end

    context 'when limit smaller than 10' do
      it 'calls receive client limit' do
        expect(client_mock).to receive(:receive_message).with(queue_url: queue.url, max_number_of_messages: 5).and_return(double(messages: [1, 2, 3]))
        expect(subject.fetch(queue, 5)).to eq([1, 2, 3])
      end
    end
  end

  context '#delete' do
    it 'calls delete message' do
      message = double(receipt_handle: 'abc')
      expect(client_mock).to receive(:delete_message).with(queue_url: queue.url, receipt_handle: 'abc')
      subject.delete(queue, message)
    end
  end
end
