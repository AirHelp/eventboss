# frozen_string_literal: true

require 'json'
require "sentry/eventboss/context_filter"
require "sentry/eventboss/helpers"

module Sentry
  module Eventboss
    class Middleware
      include Sentry::Eventboss::Helpers

      OP_NAME = "queue.process"
      SPAN_ORIGIN = "auto.queue.eventboss"

      def call(work)
        return yield unless Sentry.initialized?
        return yield unless Sentry.configuration.eventboss.performance_monitoring

        context = build_context_from_work(work)
        context_filter = Sentry::Eventboss::ContextFilter.new(context)

        Sentry.clone_hub_to_current_thread
        scope = Sentry.get_current_scope
        
        # Set tags and context
        scope.set_tags(
          queue: work.queue&.name,
          listener: work.listener&.to_s,
          component: 'eventboss'
        )
        
        scope.set_contexts(eventboss: context_filter.filtered)
        scope.set_transaction_name(context_filter.transaction_name, source: :task)
        
        # Start performance transaction
        transaction = start_transaction(scope, work.message)

        if transaction
          scope.set_span(transaction)

          latency = calculate_latency(work)
          
          set_span_data(
            transaction,
            id: work.message&.message_id,
            queue: work.queue&.name,
            event: extract_event_name(work),
            latency: latency,
            retry_count: extract_retry_count(work),
            message_size: work.message&.body&.bytesize
          )
        end

        begin
          yield
        rescue => exception
          finish_transaction(transaction, 500)
          raise
        end

        finish_transaction(transaction, 200)
        # Clear scope after successful processing
        scope.clear
      end

      private

      def build_context_from_work(work)
        {
          queue_name: work.queue&.name,
          listener_class: work.listener&.to_s,
          message_id: work.message&.message_id,
          message_body: work.message&.body,
          message_attributes: extract_message_attributes(work.message),
          approximate_receive_count: extract_receive_count(work.message),
          enqueued_at: extract_enqueued_at(work.message)
        }
      end

      def start_transaction(scope, message)
        options = {
          name: scope.transaction_name,
          source: scope.transaction_source,
          op: OP_NAME,
          origin: SPAN_ORIGIN
        }

        # Extract trace propagation headers if available
        env = extract_trace_headers(message)
        transaction = Sentry.continue_trace(env, **options)
        Sentry.start_transaction(transaction: transaction, **options)
      end

      def finish_transaction(transaction, status)
        return unless transaction

        transaction.set_http_status(status)
        transaction.finish
      end

      def extract_trace_headers(message)
        return {} unless message&.respond_to?(:attributes)
        
        attributes = message.attributes || {}
        trace_headers = {}
        
        # Look for sentry-trace and baggage in message attributes
        trace_headers['sentry-trace'] = attributes['sentry-trace'] if attributes['sentry-trace']
        trace_headers['baggage'] = attributes['baggage'] if attributes['baggage']
        
        trace_headers
      end

      def extract_event_name(work)
        # Try to extract event name from message body
        begin
          parsed = JSON.parse(work.message&.body || '{}')
          parsed['event'] || parsed['type'] || parsed['event_name']
        rescue JSON::ParserError
          nil
        end
      end

      def extract_retry_count(work)
        # SQS uses ApproximateReceiveCount to track retries
        receive_count = extract_receive_count(work.message)
        receive_count ? receive_count - 1 : 0
      end

      def extract_receive_count(message)
        return nil unless message&.respond_to?(:attributes)
        
        count = message.attributes&.fetch('ApproximateReceiveCount', nil)
        count&.to_i
      end

      def extract_enqueued_at(message)
        return nil unless message&.respond_to?(:attributes)
        
        # Try to get the sent timestamp from SQS
        sent_timestamp = message.attributes&.fetch('SentTimestamp', nil)
        if sent_timestamp
          Time.at(sent_timestamp.to_i / 1000.0) # SQS timestamp is in milliseconds
        else
          nil
        end
      end

      def extract_message_attributes(message)
        return {} unless message&.respond_to?(:attributes)
        
        message.attributes || {}
      end
    end
  end
end
