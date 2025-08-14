require 'spec_helper'

describe Eventboss::ErrorHandlers::Sentry::ContextFilter do
  # Mock Time.current for consistent testing
  let(:current_time) { Time.new(2025, 8, 11, 12, 0, 0) }
  
  before do
    allow(Time).to receive(:current).and_return(current_time)
  end

  let(:processor) { double('processor', class: double(to_s: 'TestProcessor'), object_id: 12345) }
  let(:message) do
    double('message', 
      message_id: 'msg-123',
      body: '{"event": "test"}',
      attributes: { 'SenderId' => 'test-app', 'MessageGroupId' => 'group-1' }
    )
  end

  let(:context) do
    {
      processor: processor,
      message_id: 'msg-123',
      worker_id: 'worker-1',
      name: 'test-thread',
      poller_id: 'poller-test-queue',
      queue_name: 'test-queue'
    }
  end

  subject { described_class.new(context) }

  # Mock Sentry configuration
  let(:sentry_config) do
    double('config',
      capture_processor_context: true,
      capture_message_body: false,
      capture_message_headers: true,
      max_message_body_size: 4096
    )
  end

  before do
    allow(::Sentry).to receive_message_chain(:configuration, :eventboss).and_return(sentry_config)
  end

  describe '#filtered' do
    it 'includes basic component information' do
      result = subject.filtered

      expect(result[:component]).to eq('eventboss')
      expect(result[:ruby_version]).to eq(RUBY_VERSION)
      expect(result[:processing_time]).to eq(current_time.to_f)
    end

    it 'includes processor information' do
      result = subject.filtered

      expect(result[:processor_class]).to eq('TestProcessor')
      expect(result[:processor_id]).to eq(12345)
    end

    it 'includes message and queue information' do
      result = subject.filtered

      expect(result[:message_id]).to eq('msg-123')
      expect(result[:worker_id]).to eq('worker-1')
      expect(result[:thread_name]).to eq('test-thread')
      expect(result[:poller_id]).to eq('poller-test-queue')
      expect(result[:queue_name]).to eq('test-queue')
    end

    it 'extracts queue name from poller_id when queue_name is not provided' do
      context_without_queue = context.except(:queue_name)
      filter = described_class.new(context_without_queue)

      result = filter.filtered

      expect(result[:queue_name]).to eq('test-queue')
    end

    context 'when processor supports additional context' do
      let(:enhanced_processor) do
        double('enhanced_processor',
          class: double(to_s: 'EnhancedProcessor'),
          object_id: 54321,
          current_message: message,
          started_at: current_time - 5,
          retry_count: 2,
          postponed_by: 30
        )
      end

      let(:context_with_enhanced_processor) do
        context.merge(processor: enhanced_processor)
      end

      subject { described_class.new(context_with_enhanced_processor) }

      it 'extracts processor timing information' do
        result = subject.filtered

        expect(result[:processing_started_at]).to eq((current_time - 5).to_f)
        expect(result[:processing_duration]).to eq(5.0)
      end

      it 'extracts retry information' do
        result = subject.filtered

        expect(result[:retry_count]).to eq(2)
        expect(result[:postponed_by]).to eq(30)
      end

      it 'extracts message body size when capture_message_body is false' do
        result = subject.filtered

        expect(result[:message_body_size]).to eq('{"event": "test"}'.size)
        expect(result[:message_body]).to be_nil
      end

      context 'when capture_message_body is enabled' do
        before do
          allow(sentry_config).to receive(:capture_message_body).and_return(true)
        end

        it 'includes message body when under size limit' do
          result = subject.filtered

          expect(result[:message_body]).to eq('{"event": "test"}')
          expect(result[:message_body_size]).to eq('{"event": "test"}'.size)
        end

        it 'truncates message body when over size limit' do
          large_body = 'x' * 5000
          allow(message).to receive(:body).and_return(large_body)
          allow(sentry_config).to receive(:max_message_body_size).and_return(100)

          result = subject.filtered

          expect(result[:message_body]).to eq('x' * 100 + '... (truncated)')
          expect(result[:message_body_size]).to eq(5000)
        end
      end

      it 'includes message attributes when capture_message_headers is enabled' do
        result = subject.filtered

        expect(result[:message_attributes]).to eq({
          'SenderId' => 'test-app',
          'MessageGroupId' => 'group-1'
        })
      end
    end

    context 'when context extraction fails' do
      let(:failing_processor) do
        double('failing_processor').tap do |p|
          allow(p).to receive(:class).and_return(double(to_s: 'FailingProcessor'))
          allow(p).to receive(:object_id).and_return(99999)
          allow(p).to receive(:current_message).and_raise(StandardError.new('Extraction failed'))
        end
      end

      let(:context_with_failing_processor) do
        context.merge(processor: failing_processor)
      end

      subject { described_class.new(context_with_failing_processor) }

      it 'includes error information instead of failing' do
        result = subject.filtered

        expect(result[:context_extraction_error]).to eq('Extraction failed')
      end
    end
  end

  describe '#transaction_name' do
    it 'returns transaction name based on processor class' do
      expect(subject.transaction_name).to eq('Eventboss/TestProcessor')
    end

    it 'returns transaction name based on queue when no processor' do
      context_without_processor = context.except(:processor)
      filter = described_class.new(context_without_processor)

      expect(filter.transaction_name).to eq('Eventboss/test-queue')
    end

    it 'returns default name when no processor or queue' do
      minimal_context = { worker_id: 'worker-1' }
      filter = described_class.new(minimal_context)

      expect(filter.transaction_name).to eq('Eventboss')
    end
  end
end
