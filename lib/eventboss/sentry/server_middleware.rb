module Eventboss
  module Sentry
    class ServerMiddleware < Eventboss::Middleware::Base
      OP_NAME = 'queue.process'
      SPAN_ORIGIN = 'auto.queue.eventboss'

      # since sentry has env selector, we can remove it from queue names
      QUEUES_WITHOUT_ENV = Hash.new do |hash, key|
        hash[key] = key
                      .gsub("-#{Eventboss.env}-", '-ENV-')
                      .gsub("-#{Eventboss.env}", '-ENV')
      end

      def call(work)
        return yield unless ::Sentry.initialized?

        ::Sentry.clone_hub_to_current_thread
        scope = ::Sentry.get_current_scope
        scope.clear
        scope.set_tags(queue: extract_queue_name(work), message_id: work.message.message_id)
        scope.set_transaction_name(extract_transaction_name(work), source: :task)
        transaction = start_transaction(scope)

        if transaction
          scope.set_span(transaction)
          transaction.set_data(::Sentry::Span::DataConventions::MESSAGING_MESSAGE_ID, work.message.message_id)
          transaction.set_data(::Sentry::Span::DataConventions::MESSAGING_DESTINATION_NAME, extract_queue_name(work))

          if (latency = extract_latency(work.message))
            transaction.set_data(::Sentry::Span::DataConventions::MESSAGING_MESSAGE_RECEIVE_LATENCY, latency)
          end

          if (retry_count = extract_receive_count(work.message))
            transaction.set_data(::Sentry::Span::DataConventions::MESSAGING_MESSAGE_RETRY_COUNT, retry_count)
          end
        end

        begin
          yield
        rescue StandardError
          finish_transaction(transaction, 500)
          raise
        end

        finish_transaction(transaction, 200)
      end

      def start_transaction(scope)
        options = {
          name: scope.transaction_name,
          source: scope.transaction_source,
          op: OP_NAME,
          origin: SPAN_ORIGIN
        }

        ::Sentry.start_transaction(**options)
      end

      def finish_transaction(transaction, status)
        return unless transaction

        transaction.set_http_status(status)
        transaction.finish
      end

      def extract_transaction_name(work)
        "Eventboss/#{work.listener.to_s}"
      end

      def extract_queue_name(work)
        QUEUES_WITHOUT_ENV[work.queue.name]
      end

      def extract_latency(message)
        if sent_timestamp = message.attributes.fetch('SentTimestamp', nil)
          Time.now - Time.at(sent_timestamp.to_i / 1000.0)
        end
      end

      def extract_receive_count(message)
        if receive_count = message.attributes.fetch('ApproximateReceiveCount', nil)
          receive_count.to_i - 1
        end
      end
    end
  end
end