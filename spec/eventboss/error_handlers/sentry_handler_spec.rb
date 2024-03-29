require 'spec_helper'

describe Eventboss::ErrorHandlers::Sentry do
  module Sentry; end

  subject { described_class.new }

  let(:some_error) { double(class: StandardError) }
  let(:sentry_with_scope_mock) { double(class: ::Sentry) }

  context 'when receiving some exception' do

    it 'calls Sentry.capture_exception' do
      expect(::Sentry).to receive(:with_scope).and_yield(sentry_with_scope_mock)

      expect(sentry_with_scope_mock).to receive(:set_tags).with(hash_including({ component: 'eventboss' }))
      expect(::Sentry).to receive(:capture_exception).with(some_error)

      subject.call(some_error)
    end
  end
end
