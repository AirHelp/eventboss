require 'rake'

namespace :eventboss do
  namespace :deadletter do
    desc 'Reload deadletter queue'
    task :reload, [:event_name, :source_app, :max_messages] do |task, args|
      source_app = args[:source_app]
      event_name = args[:event_name]

      # Zero means, fetch all messages
      max_messages = args[:max_messages].to_i

      # Ensure we don't fetch more than 10 messages from SQS
      batch_size = max_messages == 0 ? 10 : [10, max_messages].min

      abort "[#{task.name}] At least event name should be passed as argument" unless event_name

      queue_name = [
        Eventboss.configuration.eventboss_app_name,
        Eventboss.configuration.sns_sqs_name_infix,
        source_app,
        event_name,
        Eventboss.env
      ].compact.join('-')
      puts "[#{task.name}] Reloading #{queue_name}-deadletter (max: #{ max_messages }, batch: #{ batch_size })"
      queue = Eventboss::Queue.new("#{queue_name}-deadletter")
      send_queue = Eventboss::Queue.new(queue_name)

      puts "[#{task.name}] #{queue.url}"
      puts "[#{task.name}] to"
      puts "[#{task.name}] #{send_queue.url}"

      fetcher = Eventboss::Fetcher.new(Eventboss.configuration)
      client = fetcher.client
      total = 0
      loop do
        messages = fetcher.fetch(queue, batch_size)
        break if messages.count.zero?

        messages.each do |message|
          puts "[#{task.name}] Publishing message: #{message.body}"
          client.send_message(queue_url: send_queue.url, message_body: message.body)
          fetcher.delete(queue, message)

          total += 1
          break if max_messages > 0 && total >= max_messages
        end

        break if max_messages > 0 && total >= max_messages
      end
    end
  end
end
