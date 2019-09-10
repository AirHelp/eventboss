require 'active_record'
require 'eventboss/error_handlers/db_connection_drop_handler'

describe Eventboss::ErrorHandlers::DbConnectionDropHandler do
  subject { described_class.new }

  let(:statement_invalid_error) { double(class: ActiveRecord::StatementInvalid) }
  let(:some_error) { double(class: StandardError) }

  context 'when receives ActiveRecord::StatementInvalid exception' do
    it 'calls AR.clear_active_connections!' do
      expect(::ActiveRecord::Base).to receive(:clear_active_connections!)
      subject.call(statement_invalid_error)
    end
  end

  context 'when receives some other exception' do
    it 'doesnt call AR.clear_active_connections!' do
      expect(::ActiveRecord::Base).to_not receive(:clear_active_connections!)
      subject.call(some_error)
    end
  end
end
