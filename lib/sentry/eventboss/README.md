# Eventboss Sentry Integration

This integration provides comprehensive error reporting and performance monitoring for Eventboss using Sentry, following the same patterns established by `sentry-sidekiq` and `sentry-delayed_job`.

## Installation

Add this to your Gemfile:

```ruby
gem 'sentry-ruby'
# The integration is automatically loaded when both sentry-ruby and eventboss are available
```

## Configuration

The integration automatically configures itself when Sentry is initialized. You can customize the behavior:

```ruby
Sentry.init do |config|
  config.dsn = 'YOUR_SENTRY_DSN'
  
  # Eventboss-specific configuration
  config.eventboss.report_after_job_retries = true  # Only report after all retries exhausted
  config.eventboss.propagate_traces = true          # Enable distributed tracing
  config.eventboss.capture_job_body = false         # Capture message body (be careful with PII)
  config.eventboss.capture_headers = true           # Capture message headers/attributes
  config.eventboss.performance_monitoring = true    # Enable performance transactions
  config.eventboss.max_message_body_size = 4096     # Limit captured body size (bytes)
  
  # Exclude specific listeners from error reporting
  config.eventboss.excluded_listeners = [
    'HealthCheckListener',     # String matching
    /Test.*Listener/,          # Regex patterns
    SomeSpecificListener       # Class references
  ]
end
```

## Features

### Error Reporting with Rich Context

Automatically captures exceptions with comprehensive context:

- Queue name and message ID
- Listener class and event name
- Processing duration and retry count
- Message size and approximate receive count
- SQS message attributes

### Performance Monitoring

Creates performance transactions for each job:

- Transaction name: `Eventboss/ListenerClassName`
- Operation: `queue.process`
- Spans include messaging metadata (queue, latency, retry count)
- Latency calculation from SQS `SentTimestamp`

### Distributed Tracing

Automatically propagates traces between publishers and consumers:

- Injects `sentry-trace` and `baggage` headers when publishing
- Extracts and continues traces when processing messages
- Connects related events across services

### Intelligent Retry Handling

- Option to only report errors after all retries are exhausted
- Uses SQS `ApproximateReceiveCount` to determine retry state
- Configurable retry thresholds

### Data Privacy Controls

- Configurable message body capture (disabled by default)
- Message body size limits to prevent large payloads
- Header/attribute capture controls
- Listener class exclusion patterns

## Backward Compatibility

The integration maintains compatibility with existing Eventboss Sentry configurations:

```ruby
# This still works (deprecated)
Eventboss.configure do |config|
  config.error_handlers << Eventboss::ErrorHandlers::Sentry.new
end

# But this is preferred (automatic)
require 'sentry-eventboss'  # Auto-configures everything
```

## Manual Configuration

If you need manual control over the integration:

```ruby
# Add error handler manually
Eventboss.configuration.error_handlers << Sentry::Eventboss::ErrorHandler.new

# Add middleware manually  
Eventboss.configuration.server_middleware.add Sentry::Eventboss::Middleware
```

## Transaction Names

Transaction names follow the pattern: `Eventboss/ListenerClassName`

If the listener class can't be determined, it falls back to the event name or just `Eventboss`.

## Example Error Context

```ruby
{
  "contexts": {
    "eventboss": {
      "queue_name": "user-events-production",
      "listener_class": "UserEventListener", 
      "message_id": "abc123-def456",
      "event_name": "user.created",
      "approximate_receive_count": 2,
      "processing_duration": 0.25,
      "message_size": 1024
    }
  },
  "tags": {
    "queue": "user-events-production",
    "listener": "UserEventListener",
    "component": "eventboss"
  }
}
```

## Performance Data

Span data includes OpenTelemetry messaging conventions:

- `messaging.message.id`: SQS Message ID
- `messaging.destination.name`: Queue name  
- `messaging.operation`: "process"
- `messaging.system`: "eventboss"
- `messaging.message.receive.latency`: Processing latency in ms
- `eventboss.event_name`: Event name from message body
- `eventboss.retry_count`: Number of processing attempts
- `eventboss.message_size`: Message body size in bytes

## Migration from Legacy Integration

1. Remove manual error handler configuration:
   ```ruby
   # Remove this
   config.error_handlers << Eventboss::ErrorHandlers::Sentry.new
   ```

2. Update configuration to use new structure:
   ```ruby
   # Change from
   config.sentry_configuration.report_after_retries = true
   
   # To
   Sentry.configuration.eventboss.report_after_job_retries = true
   ```

3. Require the new integration:
   ```ruby
   require 'sentry-eventboss'
   ```

The integration will automatically migrate your settings and provide deprecation warnings for old usage patterns.
