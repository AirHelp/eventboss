require "spec_helper"

describe Eventboss::Manager do
  let(:fetcher) { double('fetcher') }
  let(:queue) { double('queue') }
  let(:sqs_msg) { double('sqs_msg') }
  let(:processor) { double('processor', jid: 123, postponed_by: postponed_by) }
  subject(:manager) { described_class.new(fetcher, nil, nil, nil, nil, nil) }

  before do
    allow(Eventboss::Logger).to receive(:info)
    allow(Eventboss::Logger).to receive(:error)
  end

  describe 'automated exception handling' do
    context 'with airbrake handler' do
      before do
        class_double('Airbrake', notify: true).as_stubbed_const
      end

      let(:processor) { double('processor', jid: 123, postponed_by: nil) }
      let(:fetcher) { double('fetcher') }

      subject do
        queue_listeners = { queue: double('processor', new: processor) }
        executor = Concurrent.global_immediate_executor
        concurrency = 1

        described_class.new(fetcher, nil, executor, queue_listeners, concurrency, [Eventboss::ErrorHandlers::Airbrake.new]).send(:assign, :queue, double('message', body: '{}'))
      end

      it 'notifies airbrake' do
        err = StandardError.new
        expect(processor).to receive(:receive).and_raise(err)
        expect(Airbrake).to receive(:notify).with(err)
        expect(fetcher).to_not receive(:delete)

        subject
      end
    end
  end

  describe '#postpone_if_needed' do
    context 'when postponed' do
      let(:postponed_by) { 10 }

      it 'changes message visibility' do
        expect(fetcher).to receive(:change_message_visibility).with(queue, sqs_msg, 10)
        manager.send(:postpone_if_needed, queue, sqs_msg, processor)
      end
    end

    context 'it works even if postponing raise error' do
      let(:postponed_by) { 10 }

      it 'changes message visibility' do
        expect(fetcher).to receive(:change_message_visibility).and_raise('Could not postpone')
        manager.send(:postpone_if_needed, queue, sqs_msg, processor)
      end
    end

    context 'when not postponed' do
      let(:postponed_by) { nil }

      it 'does not change message visibility' do
        expect(fetcher).not_to receive(:change_message_visibility)
        manager.send(:postpone_if_needed, queue, sqs_msg, processor)
      end
    end
  end
end
