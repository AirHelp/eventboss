# frozen_string_literal: true

require 'spec_helper'

describe Eventboss::ErrorHandlers::DbConnectionDropHandler do
  module ActiveRecord
    module VERSION
      STRING = '8.0.0'
    end

    class StatementInvalid < StandardError; end

    class ConnectionHandler
      def clear_active_connections!; end
    end

    class Base
      class << self
        def clear_active_connections!; end
        def connection_handler; end
      end
    end
  end

  let(:handler) { instance_double(ActiveRecord::ConnectionHandler) }

  subject { described_class.new }

  before do
    allow(ActiveRecord::Base).to receive(:connection_handler).and_return(handler)
  end

  context 'when ActiveRecord version >= 8.0.0' do
    before do
      stub_const('ActiveRecord::VERSION::STRING', '8.0.0')
    end

    it 'calls Base.clear_active_connections!' do
      expect(ActiveRecord::Base).to receive(:clear_active_connections!)
      subject.call(ActiveRecord::StatementInvalid.new)
    end
  end

  context 'when ActiveRecord version < 8.0.0' do
    before do
      stub_const('ActiveRecord::VERSION::STRING', '7.2.3')
    end

    it 'calls connection_handler.clear_active_connections!' do
      expect(handler).to receive(:clear_active_connections!)
      subject.call(ActiveRecord::StatementInvalid.new)
    end
  end

  context 'when receives a different exception' do
    before do
      stub_const('ActiveRecord::VERSION::STRING', '8.0.0')
    end

    it 'does not clear any connections' do
      expect(ActiveRecord::Base).not_to receive(:clear_active_connections!)
      expect(handler).not_to receive(:clear_active_connections!)
      subject.call(StandardError.new)
    end
  end
end
