# frozen_string_literal: true

require "spec_helper"

describe Eventboss::Queue do
  let(:name) { 'sample_queue_name' }
  let(:client_mock) { double('client_mock', get_queue_url: double(queue_url: queue_url)) }
  let(:queue_url) { double }

  subject(:queue) { described_class.new(name) }

  before do
    allow(Eventboss.configuration).to receive(:sqs_client).and_return(client_mock)
  end


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
    let(:source_app) { 'src' }
    let(:destination) { 'dst' }
    let(:event_name) { 'process_resource' }
    let(:env) { 'test' }

    subject do
      described_class.build_name(
        source_app: source_app,
        destination: destination,
        event_name: event_name,
        env: env
      )
    end

    it 'returns queue name' do
      url = "#{destination}-eventboss-#{source_app}-#{event_name}-#{env}"

      expect(subject).to eql(url)
    end

    context 'when no source_app set' do
      let(:source_app) { nil }

      it 'returns queue name' do
        url = "#{destination}-eventboss-#{event_name}-#{env}"

        expect(subject).to eql(url)
      end
    end
  end

  describe '.build' do
    subject { described_class.build(**queue_params) }

    let(:queue_params) do
      {
        source_app: 'chyba',
        destination: 'ze',
        event_name: 'o to',
        env: 'pytasz'
      }
    end

    before do
      allow(Eventboss::Queue).to receive(:build_name).with(queue_params).and_return('qname')
    end

    it 'creates a queue' do
      expect(subject).to be_instance_of(Eventboss::Queue)
    end

    it 'uses .build_name' do
      subject
      expect(Eventboss::Queue).to have_received(:build_name).with(queue_params)
    end
  end

  describe '#arn' do
    subject { described_class.new('wieloryb') }

    let(:queue_params) do
      {
        source_app: 'wieloryb',
        destination: 'gdansk',
        event_name: 'EV',
        env: 'we did it'
      }
    end

    before do
      allow(Eventboss.configuration).to receive(:eventboss_region).and_return('R')
      allow(Eventboss.configuration).to receive(:eventboss_account_id).and_return('idkfa')
    end

    it 'includes name' do
      expect(subject.arn).to include('wieloryb')
    end

    it 'uses eventboss region' do
      subject.arn
      expect(Eventboss.configuration).to have_received(:eventboss_region)
    end

    it 'uses eventboss account id' do
      subject.arn
      expect(Eventboss.configuration).to have_received(:eventboss_account_id)
    end
  end

  describe '#to_s' do
    subject { described_class.new('double-negative') }

    it { expect(subject.to_s).to eql('<Eventboss::Queue: double-negative>') }
  end
end
