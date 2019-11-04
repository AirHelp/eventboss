require "spec_helper"

describe Eventboss::Listener do
  before do
    stub_const 'Eventboss::Listener::ACTIVE_LISTENERS', {}

    stub_const 'Listener1', Class.new
    Listener1.class_eval do
      include Eventboss::Listener
      eventboss_options source_app: 'app1', event_name: 'transaction_created'
    end

    stub_const 'GenericListener1', Class.new
    GenericListener1.class_eval do
      include Eventboss::Listener
      eventboss_options event_name: 'transaction_created', destination_app: 'dest_app'
    end
  end

  context '#jid' do
    it 'creates unique jid for the job' do
      expect(Listener1.new.jid).not_to be_nil
      expect(Listener1.new.jid).not_to eq(Listener1.new.jid)
    end
  end

  context '#ACTIVE_LISTENERS' do
    it 'adds the class to active listeners hash' do
      expect(Eventboss::Listener::ACTIVE_LISTENERS).to eq(
        "transaction_created" => { listener: GenericListener1, destination_app: 'dest_app' },
        "app1-transaction_created" => { listener: Listener1, destination_app: nil }
      )
    end
  end

  context '#postponed_by' do
    it 's nil when not called' do
      expect(Listener1.new.postponed_by).to be_nil
    end

    it 's set to the value passed to postpone_by' do
      listener = Listener1.new
      listener.postpone_by(60)
      expect(listener.postponed_by).to eq(60)
    end
  end
end
