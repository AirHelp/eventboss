require 'spec_helper'

describe Eventboss::Middleware do
  class MyMiddleware < Eventboss::Middleware::Base
    def call
      options[:calls] << self
    end
  end

  class MyOtherMiddleware < MyMiddleware
  end

  describe 'chain' do
    subject(:chain) { Eventboss::Middleware::Chain.new }

    describe '#add' do
      it 'adds entry at the end of the chain' do
        chain.add MyMiddleware
        chain.add MyOtherMiddleware
        expect(chain.entries.map(&:klass)).to eq [
          MyMiddleware,
          MyOtherMiddleware
        ]
      end
    end

    describe '#invoke' do
      let(:calls) { [] }

      it 'calls each middleware in order' do
        chain.add MyMiddleware, calls: calls
        chain.add MyOtherMiddleware, calls: calls
        chain.invoke do
          expect(calls).to contain_exactly(
            an_instance_of(MyMiddleware),
            an_instance_of(MyOtherMiddleware)
          )
        end
      end
    end
  end
end
