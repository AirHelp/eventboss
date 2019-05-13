require "spec_helper"

describe Eventboss::Polling::Basic do
  let(:queues) { ['a', 'b', 'c'] }
  let(:timer) { FixedTimer.new }

  subject(:basic) { described_class.new(queues) }

  it 'returns next queues one by one' do
    expect(basic.next_queue).to eq('a')
    expect(basic.next_queue).to eq('b')
    expect(basic.next_queue).to eq('c')
    expect(basic.next_queue).to eq('a')
  end

  it 'skips the queue when paused' do
    basic.messages_found('b', 0)
    basic.messages_found('c', 1)
    expect(basic.next_queue).to eq('a')
    expect(basic.next_queue).to eq('c')
    expect(basic.next_queue).to eq('a')
  end

  it 'returns nil when all skipped' do
    basic.messages_found('a', 0)
    basic.messages_found('b', 0)
    basic.messages_found('c', 0)
    expect(basic.next_queue).to be_nil
  end

  it 'consuming the same queue if still has messages' do
    basic.messages_found('a', 1)
    basic.messages_found('b', 1)
    basic.messages_found('c', 1)

    expect(basic.next_queue).to eq('a')
    basic.messages_found('a', 0)

    expect(basic.next_queue).to eq('b')
    basic.messages_found('b', 1)

    expect(basic.next_queue).to eq('b')
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

  # This ensures that when there is any paused queues when
  # the time has expired, the cycle will start from scratch
  it 'restarts work from scratch ' do
    pool = described_class.new(queues, timer)

    pool.messages_found('a', 1)
    pool.messages_found('b', 1)
    pool.messages_found('c', 1)

    expect(pool.next_queue).to eq('a')
    pool.messages_found('a', 0)

    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 0)

    # enough time passed, will reset to the beginning
    # whereas in TimedRoundRobin, it will go to `c`
    timer.at(timer.now + 4)
    expect(pool.next_queue).to eq('a')
    pool.messages_found('a', 0)

    expect(pool.next_queue).to eq('b')
    pool.messages_found('b', 0)

    expect(pool.next_queue).to eq('c')
    pool.messages_found('c', 0)

    expect(pool.next_queue).to be_nil
  end
end
