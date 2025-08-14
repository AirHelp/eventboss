require 'spec_helper'

describe Sentry::Eventboss do
  # Mock Sentry methods
  module Sentry
    class << self
      def with_scope
        scope = double('scope')
        yield(scope)
      end

      def capture_exception(exception, hint: {})
        # Mock implementation
      end
    end
  end

  let(:exception) { StandardError.new('test error') }
  let(:contexts) { { eventboss: { processor_class: 'TestProcessor' } } }
  let(:hint) { { background: false } }

  describe '.capture_exception' do
    it 'creates a new scope and sets contexts' do
      scope = double('scope')
      expect(::Sentry).to receive(:with_scope).and_yield(scope)
      expect(scope).to receive(:set_context).with(:eventboss, { processor_class: 'TestProcessor' })
      expect(scope).to receive(:set_tags).with(
        component: 'eventboss',
        eventboss_version: 'unknown'
      )
      expect(::Sentry).to receive(:capture_exception).with(exception, hint: hint)

      described_class.capture_exception(exception, contexts: contexts, hint: hint)
    end

    it 'sets eventboss version when available' do
      stub_const('::Eventboss::VERSION', '1.2.3')
      scope = double('scope')
      expect(::Sentry).to receive(:with_scope).and_yield(scope)
      expect(scope).to receive(:set_context).with(:eventboss, { processor_class: 'TestProcessor' })
      expect(scope).to receive(:set_tags).with(
        component: 'eventboss',
        eventboss_version: '1.2.3'
      )
      expect(::Sentry).to receive(:capture_exception).with(exception, hint: hint)

      described_class.capture_exception(exception, contexts: contexts, hint: hint)
    end

    it 'works with multiple contexts' do
      multiple_contexts = {
        eventboss: { processor_class: 'TestProcessor' },
        runtime: { memory_usage: '100MB' }
      }

      scope = double('scope')
      expect(::Sentry).to receive(:with_scope).and_yield(scope)
      expect(scope).to receive(:set_context).with(:eventboss, { processor_class: 'TestProcessor' })
      expect(scope).to receive(:set_context).with(:runtime, { memory_usage: '100MB' })
      expect(scope).to receive(:set_tags).with(
        component: 'eventboss',
        eventboss_version: 'unknown'
      )
      expect(::Sentry).to receive(:capture_exception).with(exception, hint: hint)

      described_class.capture_exception(exception, contexts: multiple_contexts, hint: hint)
    end

    it 'works with no contexts' do
      scope = double('scope')
      expect(::Sentry).to receive(:with_scope).and_yield(scope)
      expect(scope).to receive(:set_tags).with(
        component: 'eventboss',
        eventboss_version: 'unknown'
      )
      expect(::Sentry).to receive(:capture_exception).with(exception, hint: hint)

      described_class.capture_exception(exception, hint: hint)
    end
  end
end
