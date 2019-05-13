require "spec_helper"

describe Eventboss do
  it "has a version number" do
    expect(Eventboss::VERSION).not_to be nil
  end

  context '#start' do
    it 'runs start on runner' do
      expect(Eventboss::Runner).to receive(:start)
      Eventboss.listen
    end
  end

  describe '#sender' do
    let(:event_name) { 'fake_event' }
    let(:destination_app) { 'fake_app' }
    let(:configuration) do
      Eventboss::Configuration.new.tap do |c|
        c.eventboss_app_name = 'app_name1'
        c.eventboss_region = 'dummy'
      end
    end

    subject { described_class.sender(event_name, destination_app) }

    before do
      allow(described_class).to receive(:configuration) { configuration }
    end

    it 'calls Eventboss::Sender' do
      expect(Eventboss::Sender).to receive(:new).with(hash_including(:queue, :client))

      subject
    end
  end
end
