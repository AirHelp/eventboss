require 'spec_helper'

describe Eventboss::UnitOfWork do
  subject do
    described_class.new(queue, listener_class, message)
  end

  let(:queue) { double('queue', url: 'url') }
  let(:client) { double('client') }
  let(:message) do
    double('message', message_id: 'id', body: '{}', receipt_handle: 'handle')
  end

  context 'with successful job' do
    let(:listener_class) do
      Class.new do
        include Eventboss::Listener

        def receive(payload)
        end
      end
    end

    it 'runs the job and deletes the message' do
      expect_any_instance_of(listener_class).to receive(:receive).with(JSON.parse(message.body))
      expect(client)
        .to receive(:delete_message).with(queue_url: 'url', receipt_handle: 'handle')

      subject.run(client)
    end
  end

  context 'with successful job and postpone by' do
    let(:listener_class) do
      Class.new do
        include Eventboss::Listener

        def initialize
          postpone_by(100)
        end

        def receive(payload)
        end
      end
    end

    it 'does not delete the message but change msg visibility' do
      expect(client).not_to receive(:delete_message)
      expect(client).to receive(:change_message_visibility).with(
        queue_url: queue.url,
        receipt_handle: message.receipt_handle,
        visibility_timeout: 100
      )

      subject.run(client)
    end
  end


  context 'with failed job' do
    let(:listener_class) do
      Class.new do
        include Eventboss::Listener

        def receive(payload)
          raise RuntimeError
        end
      end
    end

    it 'does not cleanup message' do
      expect(client).not_to receive(:delete_message)

      subject.run(client)
    end
  end

  context 'with failed job and postpone by' do
    let(:listener_class) do
      Class.new do
        include Eventboss::Listener

        def initialize
          postpone_by(100)
        end

        def receive(payload)
          raise RuntimeError
        end
      end
    end

    it 'does not delete the message but change msg visibility' do
      expect(client).not_to receive(:delete_message)
      expect(client).to receive(:change_message_visibility).with(
        queue_url: queue.url,
        receipt_handle: message.receipt_handle,
        visibility_timeout: 100
      )

      subject.run(client)
    end
  end

  context 'with invalid JSON payload' do
    let(:listener_class) do
      Class.new do
        include Eventboss::Listener

        def receive(payload)
        end
      end
    end

    let(:message) do
      double('message', message_id: 'id', body: '.')
    end

    it 'does not run the job' do
      expect(client).not_to receive(:delete_message)

      subject.run(client)
    end
  end
end
