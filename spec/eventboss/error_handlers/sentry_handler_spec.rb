require 'spec_helper'

describe Eventboss::ErrorHandlers::Sentry do
  # Mock Sentry modules
  module Sentry
    class << self
      attr_accessor :initialized, :current_scope, :configuration

      def initialized?
        @initialized ||= true
      end

      def get_current_scope
        @current_scope ||= double('scope', set_transaction_name: nil, clear: nil)
      end

      def configuration
        @configuration ||= double('config', eventboss: eventboss_config)
      end

      private

      def eventboss_config
        double('eventboss_config', 
          excluded_processor?: false,
          report_after_job_retries: false,
          capture_processor_context: true,
          capture_message_body: false,
          capture_message_headers: true,
          max_message_body_size: 4096
        )
      end
    end

    module Eventboss
      def self.capture_exception(exception, contexts: {}, hint: {})
        # Mock implementation
      end
    end
  end

  subject { described_class.new }

  let(:some_error) { StandardError.new("Test error") }
  let(:processor) { double('processor', class: double(to_s: 'TestProcessor')) }
  let(:context) do
    {
      processor: processor,
      message_id: 'test-message-123',
      queue_name: 'test-queue',
      worker_id: 'worker-1'
    }
  end

  before do
    # Reset Sentry state
    Sentry.initialized = true
    allow(::Sentry).to receive(:initialized?).and_return(true)
    allow(::Sentry).to receive(:get_current_scope).and_return(Sentry.get_current_scope)
    allow(::Sentry).to receive(:configuration).and_return(Sentry.configuration)
    allow(::Sentry::Eventboss).to receive(:capture_exception)
  end

  context 'when Sentry is initialized' do
    it 'captures the exception with rich context' do
      expect(::Sentry::Eventboss).to receive(:capture_exception).with(
        some_error,
        hash_including(
          contexts: hash_including(:eventboss),
          hint: { background: false }
        )
      )

      subject.call(some_error, context)
    end

    it 'sets transaction name based on processor class' do
      scope = Sentry.get_current_scope
      expect(scope).to receive(:set_transaction_name).with('Eventboss/TestProcessor', source: :task)

      subject.call(some_error, context)
    end

    it 'clears the scope after processing' do
      scope = Sentry.get_current_scope
      expect(scope).to receive(:clear)

      subject.call(some_error, context)
    end
  end

  context 'when Sentry is not initialized' do
    before do
      allow(::Sentry).to receive(:initialized?).and_return(false)
    end

    it 'does not capture the exception' do
      expect(::Sentry::Eventboss).not_to receive(:capture_exception)

      subject.call(some_error, context)
    end
  end

  context 'when processor is excluded' do
    before do
      config = Sentry.configuration.eventboss
      allow(config).to receive(:excluded_processor?).with(processor).and_return(true)
    end

    it 'does not capture the exception' do
      expect(::Sentry::Eventboss).not_to receive(:capture_exception)

      subject.call(some_error, context)
    end
  end

  context 'when report_after_job_retries is enabled' do
    let(:retryable_processor) { double('processor', class: double(to_s: 'RetryableProcessor'), retryable?: true) }
    let(:context_with_retryable) { context.merge(processor: retryable_processor) }

    before do
      config = Sentry.configuration.eventboss
      allow(config).to receive(:report_after_job_retries).and_return(true)
    end

    it 'skips reporting for retryable jobs that have not exceeded retry limit' do
      expect(::Sentry::Eventboss).not_to receive(:capture_exception)

      subject.call(some_error, context_with_retryable)
    end
  end

  describe 'context filtering' do
    it 'creates a context filter with the provided context' do
      expect(Eventboss::ErrorHandlers::Sentry::ContextFilter).to receive(:new).with(context).and_call_original

      subject.call(some_error, context)
    end
  end
end
