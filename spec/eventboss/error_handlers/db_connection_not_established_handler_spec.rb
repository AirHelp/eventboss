require 'spec_helper'

describe Eventboss::ErrorHandlers::DbConnectionNotEstablishedHandler do
  module ActiveRecord
    class ConnectionNotEstablished
    end

    class Base
      def self.connection; end
    end
  end

  subject { described_class.new }

  let(:some_error) { double(class: StandardError) }

  context 'when receiving ActiveRecord::ConnectionNotEstablished exception' do
    it 'calls AR.connection.reconnect!' do
      expect(::ActiveRecord::Base.connection).to receive(:reconnect!)
      subject.call(::ActiveRecord::ConnectionNotEstablished.new)
    end
  end

  context 'when receives some other exception' do
    it 'does not call AR.connection.reconnect!' do
      expect(::ActiveRecord::Base.connection).to_not receive(:reconnect!)
      subject.call(some_error)
    end
  end
end
