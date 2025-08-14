# frozen_string_literal: true

require 'eventboss/error_handlers/sentry/context_filter'
require 'eventboss/error_handlers/sentry/helpers'

module Eventboss
  module Middleware
    class SentryContext < Eventboss::Middleware::Base
      include Eventboss::ErrorHandlers::Sentry::Helpers

      OP_NAME = "queue.process"
      SPAN_ORIGIN = "auto.queue.eventboss"

      def call(work)
        return yield unless ::Sentry.initialized?
        
        # Check if this listener should be excluded
        config = Eventboss.configuration.sentry_configuration
        if config.excluded_listener?(work.listener)
          return yield
        end

        # Skip performance monitoring if disabled
        unless config.performance_monitoring
          # Just call without transaction tracking
          return ::Sentry.with_scope do |scope|
            context = build_enhanced_context(work)
            context_filter = Eventboss::ErrorHandlers::Sentry::ContextFilter.new(context)
            
            scope.set_tags(component: 'eventboss', queue: work.queue.name, message_id: work.message.message_id)
            scope.set_contexts(eventboss: context_filter.filtered)
            scope.set_transaction_name(context_filter.transaction_name, source: :task)
            
            yield
          end
        end

        # Build enriched context
        context = build_enhanced_context(work)
        context_filter = Eventboss::ErrorHandlers::Sentry::ContextFilter.new(context)

        ::Sentry.clone_hub_to_current_thread
        scope = ::Sentry.get_current_scope
        
        # Set comprehensive tags and context
        scope.set_tags(
          component: 'eventboss',
          queue: work.queue.name,
          message_id: work.message.message_id
        )
        
        # Add event-specific tags if available
        if message_body = parse_message_body(work.message.body)
          if event_name = message_body['event']
            scope.set_tags(event: event_name)
            context[:event_name] = event_name
          end
          if source_app = message_body['source_app']
            scope.set_tags(source_app: source_app)
            context[:source_app] = source_app
          end
        end
        
        # Set rich context data
        scope.set_contexts(eventboss: context_filter.filtered)
        scope.set_transaction_name(context_filter.transaction_name, source: :task)
        
        # Start performance transaction with trace propagation
        transaction = start_transaction(scope, work.message)

        if transaction
          scope.set_span(transaction)

          # Set comprehensive span data
          set_span_data(
            transaction,
            id: work.message.message_id,
            queue: work.queue.name,
            event: context[:event_name],
            latency: calculate_message_latency(work.message),
            retry_count: get_retry_count(work.message),
            message_size: work.message.body&.bytesize
          )
        end

        start_time = Time.current

        begin
          yield
        rescue Exception => e
          # Set error context
          scope.set_extra(:processing_duration, Time.current - start_time)
          scope.set_extra(:error_during_processing, true)
          
          finish_transaction(transaction, 500)
          
          # Let the error handler capture with full context
          raise
        end

        # Set success metrics
        scope.set_extra(:processing_duration, Time.current - start_time)
        finish_transaction(transaction, 200)
        
        # Clear scope after successful processing
        scope.clear
      end

      private

      def build_enhanced_context(work)
        config = Eventboss.configuration.sentry_configuration
        
        context = {
          queue_name: work.queue.name,
          listener_class: work.listener.to_s,
          message_id: work.message.message_id,
          retry_count: get_retry_count(work.message),
          enqueued_at: get_enqueued_at(work.message)
        }

        # Add message body if configuration allows it
        if config.capture_message_body && work.message.body
          body_size = work.message.body.bytesize
          if body_size <= config.max_message_body_size
            context[:body] = work.message.body
          else
            context[:body_truncated] = true
            context[:body_size] = body_size
          end
        end

        # Add message attributes if configuration allows it
        if config.capture_message_headers
          context[:message_attributes] = get_message_attributes(work.message)
        end

        context
      end

      def parse_message_body(body)
        JSON.parse(body) if body
      rescue JSON::ParserError
        nil
      end

      def get_retry_count(message)
        # Try to extract retry count from message attributes
        return 0 unless message.respond_to?(:attributes) && message.attributes
        
        retry_count = message.attributes['ApproximateReceiveCount']
        retry_count ? retry_count.to_i - 1 : 0
      rescue
        0
      end

      def get_enqueued_at(message)
        # Try to extract enqueue time from message attributes
        return nil unless message.respond_to?(:attributes) && message.attributes
        
        if timestamp = message.attributes['SentTimestamp']
          Time.at(timestamp.to_i / 1000.0)
        end
      rescue
        nil
      end

      def get_message_attributes(message)
        return {} unless message.respond_to?(:attributes) && message.attributes
        
        message.attributes
      rescue
        {}
      end

      def calculate_message_latency(message)
        enqueued_at = get_enqueued_at(message)
        return nil unless enqueued_at
        
        ((Time.current - enqueued_at) * 1000).round
      rescue
        nil
      end

      def start_transaction(scope, message)
        options = {
          name: scope.transaction_name,
          source: scope.transaction_source,
          op: OP_NAME,
          origin: SPAN_ORIGIN
        }

        # Look for trace propagation headers in message attributes
        env = extract_trace_headers_from_message(message)
        transaction = ::Sentry.continue_trace(env, **options)
        ::Sentry.start_transaction(transaction: transaction, **options)
      end

      def extract_trace_headers_from_message(message)
        return {} unless message.respond_to?(:attributes) && message.attributes&.is_a?(Hash) && !message.attributes.empty?
        
        attributes = message.attributes
        trace_headers = {}
        
        # Try direct key lookup first (most common case)
        if sentry_trace = attributes['sentry-trace'] || attributes['sentry_trace'] || attributes['Sentry-Trace']
          trace_headers['sentry-trace'] = sentry_trace
        end
        
        if baggage = attributes['baggage'] || attributes['Baggage']
          trace_headers['baggage'] = baggage
        end
        
        # Fallback to case-insensitive search only if direct lookup failed
        if trace_headers.empty?
          attributes.each do |key, value|
            key_str = key.to_s
            case key_str.downcase
            when 'sentry-trace', 'sentry_trace'
              trace_headers['sentry-trace'] = value
              break if trace_headers.size == 2
            when 'baggage'
              trace_headers['baggage'] = value
              break if trace_headers.size == 2
            end
          end
        end
        
        trace_headers
      rescue => e
        # Return empty hash if any error occurs during extraction
        {}
      end

      def finish_transaction(transaction, status)
        return unless transaction

        transaction.set_http_status(status)
        transaction.finish
      end
    end
  end
end
