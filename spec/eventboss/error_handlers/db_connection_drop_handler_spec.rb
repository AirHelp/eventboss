require 'spec_helper'

describe Eventboss::ErrorHandlers::DbConnectionDropHandler do
  module ActiveRecord
    class StatementInvalid
    end

    class Base
      def self.clear_active_connections!; end
    end
  end

  subject { described_class.new }

  let(:some_error) { double(class: StandardError) }

  context 'when receives ActiveRecord::StatementInvalid exception' do
    it 'calls AR.clear_active_connections!' do
      expect(ActiveRecord::Base).to receive(:clear_active_connections!)
      subject.call(ActiveRecord::StatementInvalid.new)
    end
  end

  context 'when receives some other exception' do
    it 'doesnt call AR.clear_active_connections!' do
      expect(::ActiveRecord::Base).to_not receive(:clear_active_connections!)
      subject.call(some_error)
    end
  end
end
