require "spec_helper"

describe Eventboss::Queue do
  let(:name) { 'sample_queue_name' }
  let(:client_mock) { double('client_mock', get_queue_url: double(queue_url: queue_url))}
  let(:queue_url) { double }
  let(:configuration) do
    Eventboss::Configuration.new.tap do |config|
      config.sqs_client = client_mock
    end
  end

  subject(:queue) { described_class.new(name, configuration) }

  context '#name' do
    it 'returns name set in initializer' do
      expect(queue.name).to eq(name)
    end
  end

  context '#url' do
    before do
      Eventboss.configure do |config|
        config.eventboss_region = 'us-east-1'
        config.eventboss_account_id = '12345'
      end
    end

    it 'returns url for the queue' do
      expect(queue.url).to eq(queue_url)
    end
  end

  context '#comparable' do
    context 'when equal' do
      it 'returns true' do
        expect(Eventboss::Queue.new('123').eql?(Eventboss::Queue.new('123'))).to be_truthy
      end
    end
  end

  describe '.build_name' do
    let(:source) { 'src' }
    let(:destination) { 'dst' }
    let(:event) { 'process_resource' }
    let(:env) { 'test' }
    let(:generic) { false }

    subject do
      described_class.build_name(
        source: source,
        destination: destination,
        event: event,
        env: env,
        generic: generic
      )
    end

    it 'returns queue name' do
      url = "#{destination}-eventboss-#{source}-#{event}-#{env}"

      expect(subject).to eql(url)
    end

    context 'when generic is true' do
      let(:generic) { true }

      it 'returns queue name' do
        url = "#{destination}-eventboss-#{event}-#{env}"

        expect(subject).to eql(url)
      end
    end
  end
end
