require "spec_helper"

describe Eventboss::Polling::TimedRoundRobin do
  let(:queues) { ['a', 'b', 'c'] }
  let(:timer) { FixedTimer.new }

  subject(:pool) { described_class.new(queues) }

  it 'returns next queues one by one' do
    expect(pool.next_queue).to eq('a')
    expect(pool.next_queue).to eq('b')
    expect(pool.next_queue).to eq('c')
    expect(pool.next_queue).to eq('a')
  end

  it 'skips the queue when paused' do
    pool.messages_found('b', 0)
    pool.messages_found('c', 1)
    expect(pool.next_queue).to eq('a')
    expect(pool.next_queue).to eq('c')
    expect(pool.next_queue).to eq('a')
  end

  it 'returns nil when all skipped' do
    pool.messages_found('a', 0)
    pool.messages_found('b', 0)
    pool.messages_found('c', 0)
    expect(pool.next_queue).to be_nil
  end

  it 'always goes to the next queue' do
    pool.messages_found('a', 1)
    pool.messages_found('b', 1)
    pool.messages_found('c', 1)

    expect(pool.next_queue).to eq('a')
    pool.messages_found('a', 0)

    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 1)

    expect(pool.next_queue).to eq('c')
  end

  it 'skips paused queues' do
    pool = described_class.new(queues, timer)

    pool.messages_found('a', 1)
    pool.messages_found('b', 1)
    pool.messages_found('c', 1)

    expect(pool.next_queue).to eq('a')
    pool.messages_found('a', 0)

    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 1)

    expect(pool.next_queue).to eq('c')
    pool.messages_found('c', 1)

    # `a` was paused for 2 seconds, next to pick up is `b`
    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 0)

    expect(pool.next_queue).to eq('c')
    pool.messages_found('c', 0)

    # all queues paused, dispatcher will sleep
    expect(pool.next_queue).to be_nil
  end

  it 'pauses for two seconds' do
    pool = described_class.new(%w(a b), timer)

    pool.messages_found('a', 1)
    pool.messages_found('b', 1)

    expect(pool.next_queue).to eq('a')
    pool.messages_found('a', 0)

    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 0)

    # will pause the dispatcher
    expect(pool.next_queue).to be_nil
    timer.at(timer.now + 1)

    # will pause the dispatcher
    expect(pool.next_queue).to be_nil
    timer.at(timer.now + 1)

    expect(pool.next_queue).to eq('a')
  end

  # This ensures that next queue is picked up, even if
  # queue `a` was paused for enough time to be next
  it 'continues to the next available queue' do
    pool = described_class.new(queues, timer)

    pool.messages_found('a', 1)
    pool.messages_found('b', 1)
    pool.messages_found('c', 1)

    expect(pool.next_queue).to eq('a')
    pool.messages_found('a', 1)
    timer.at(timer.now + 1)

    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 0)

    # enough time passed, should continue on the next queue
    timer.at(timer.now + 4)
    expect(pool.next_queue).to eq('c')
    pool.messages_found('c', 0)

    expect(pool.next_queue).to eq('a')
  end
end
