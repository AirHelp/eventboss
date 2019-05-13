require "spec_helper"

describe Eventboss::Listener do
  class Listener1
    include Eventboss::Listener
    eventboss_options source_app: 'app1', event_name: 'transaction_created'
  end

  class GenericListener1
    include Eventboss::Listener
    eventboss_options event_name: 'transaction_created'
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
        "transaction_created" => GenericListener1,
        "app1-transaction_created" => Listener1
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
