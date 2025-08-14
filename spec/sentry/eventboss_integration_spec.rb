# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Sentry Eventboss Integration' do
  before do
    # Mock Sentry to avoid actual initialization
    allow(Sentry).to receive(:initialized?).and_return(true)
    allow(Sentry).to receive(:clone_hub_to_current_thread)
    allow(Sentry).to receive(:get_current_scope).and_return(double('scope', 
      set_tags: nil,
      set_contexts: nil,
      set_transaction_name: nil,
      set_span: nil,
      clear: nil,
      transaction_name: nil,
      transaction_source: nil
    ))
    allow(Sentry).to receive(:continue_trace).and_return(double('transaction'))
    allow(Sentry).to receive(:start_transaction).and_return(double('transaction', 
      set_data: nil,
      set_http_status: nil,
      finish: nil
    ))
  end

  describe 'auto-configuration' do
    it 'adds Sentry error handler when integration is loaded' do
      require 'sentry-eventboss'
      
      # Simulate auto-configuration
      Sentry::Eventboss.auto_configure_eventboss
      
      error_handlers = Eventboss.configuration.error_handlers
      expect(error_handlers.any? { |h| h.is_a?(Sentry::Eventboss::ErrorHandler) }).to be true
    end

    it 'adds Sentry middleware when integration is loaded' do
      require 'sentry-eventboss'
      
      # Simulate auto-configuration
      Sentry::Eventboss.auto_configure_eventboss
      
      middleware_entries = Eventboss.configuration.server_middleware.entries
      expect(middleware_entries.any? { |e| e.klass == Sentry::Eventboss::Middleware }).to be true
    end
  end

  describe Sentry::Eventboss::ErrorHandler do
    let(:error_handler) { Sentry::Eventboss::ErrorHandler.new }
    let(:exception) { StandardError.new('Test error') }
    let(:context) do
      {
        queue_name: 'test-queue',
        listener_class: 'TestListener',
        message_id: 'msg-123',
        retry_count: 1
      }
    end

    it 'captures exceptions with context' do
      expect(Sentry::Eventboss).to receive(:capture_exception).with(
        exception,
        contexts: { eventboss: anything },
        hint: { background: false }
      )

      error_handler.call(exception, context)
    end

    it 'skips reporting when listener is excluded' do
      # Mock configuration
      config = double('config', excluded_listener?: true)
      allow(Sentry.configuration).to receive(:eventboss).and_return(config)

      expect(Sentry::Eventboss).not_to receive(:capture_exception)

      error_handler.call(exception, context.merge(listener_class: 'ExcludedListener'))
    end
  end

  describe Sentry::Eventboss::ContextFilter do
    let(:context) do
      {
        queue_name: 'test-queue',
        listener_class: 'TestListener',
        message_id: 'msg-123',
        message_body: '{"event": "test.event", "data": "sensitive"}',
        message_attributes: { 'attr1' => 'value1' }
      }
    end

    let(:context_filter) { Sentry::Eventboss::ContextFilter.new(context) }

    describe '#transaction_name' do
      it 'returns listener-based transaction name' do
        expect(context_filter.transaction_name).to eq('Eventboss/TestListener')
      end

      it 'falls back to event name when no listener class' do
        context_without_listener = context.except(:listener_class)
        filter = Sentry::Eventboss::ContextFilter.new(context_without_listener)
        expect(filter.transaction_name).to eq('Eventboss/test.event')
      end

      it 'falls back to Eventboss when no listener or event' do
        minimal_context = { queue_name: 'test-queue' }
        filter = Sentry::Eventboss::ContextFilter.new(minimal_context)
        expect(filter.transaction_name).to eq('Eventboss')
      end
    end

    describe '#filtered' do
      it 'removes sensitive data based on configuration' do
        # Mock configuration to exclude job body
        config = double('config', 
          capture_job_body: false,
          capture_headers: true,
          max_message_body_size: 1000
        )
        allow(Sentry.configuration).to receive(:eventboss).and_return(config)

        filtered = context_filter.filtered
        expect(filtered).not_to have_key(:message_body)
        expect(filtered).to have_key(:message_attributes)
      end

      it 'truncates large message bodies' do
        config = double('config',
          capture_job_body: true,
          capture_headers: true,
          max_message_body_size: 10
        )
        allow(Sentry.configuration).to receive(:eventboss).and_return(config)

        filtered = context_filter.filtered
        expect(filtered[:message_body]).to include('[truncated]')
      end
    end
  end

  describe Sentry::Eventboss::Middleware do
    let(:middleware) { Sentry::Eventboss::Middleware.new }
    let(:work) do
      double('work',
        queue: double('queue', name: 'test-queue'),
        listener: double('listener', to_s: 'TestListener'),
        message: double('message',
          message_id: 'msg-123',
          body: '{"event": "test.event"}',
          attributes: { 'SentTimestamp' => '1234567890000' }
        )
      )
    end

    before do
      # Mock configuration
      config = double('config', performance_monitoring: true)
      allow(Sentry.configuration).to receive(:eventboss).and_return(config)
    end

    it 'creates performance transaction for job processing' do
      expect(Sentry).to receive(:start_transaction).and_call_original

      middleware.call(work) { 'result' }
    end

    it 'sets span data with messaging information' do
      transaction = double('transaction', set_data: nil, set_http_status: nil, finish: nil)
      allow(Sentry).to receive(:start_transaction).and_return(transaction)

      expect(transaction).to receive(:set_data).with('messaging.message.id', 'msg-123')
      expect(transaction).to receive(:set_data).with('messaging.destination.name', 'test-queue')

      middleware.call(work) { 'result' }
    end

    it 'finishes transaction with success status' do
      transaction = double('transaction', set_data: nil, set_http_status: nil, finish: nil)
      allow(Sentry).to receive(:start_transaction).and_return(transaction)

      expect(transaction).to receive(:set_http_status).with(200)
      expect(transaction).to receive(:finish)

      middleware.call(work) { 'result' }
    end

    it 'finishes transaction with error status on exception' do
      transaction = double('transaction', set_data: nil, set_http_status: nil, finish: nil)
      allow(Sentry).to receive(:start_transaction).and_return(transaction)

      expect(transaction).to receive(:set_http_status).with(500)
      expect(transaction).to receive(:finish)

      expect do
        middleware.call(work) { raise StandardError, 'Test error' }
      end.to raise_error(StandardError)
    end
  end
end
