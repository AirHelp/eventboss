require 'spec_helper'

describe Eventboss::ErrorHandlers::Rollbar do
  module Rollbar
    def error(error); end
  end

  subject { described_class.new }

  let(:some_error) { double(class: StandardError) }

  context 'when receiving some exception' do
    it 'calls Rollbar.error' do
      expect(::Rollbar).to receive(:error).with(some_error, hash_including({ component: 'eventboss' }))
      subject.call(some_error)
    end

    it 'includes use_exception_level_filters option' do
      option = { use_exception_level_filters: true }

      expect(::Rollbar).to receive(:error).with(some_error, hash_including(option))
      subject.call(some_error)
    end
  end
end
