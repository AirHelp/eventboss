# Enhanced Sentry Configuration for Eventboss
# This example shows how to configure the new Sentry integration

require 'sentry-ruby'
require 'sentry-eventboss'

Sentry.init do |config|
  config.dsn = 'YOUR_SENTRY_DSN'
  config.environment = Rails.env
  
  # Enable performance monitoring
  config.traces_sample_rate = 0.1
  
  # Configure Eventboss-specific options
  config.eventboss.report_after_job_retries = true
  config.eventboss.propagate_traces = true
  config.eventboss.capture_job_body = false # Be careful with sensitive data
  config.eventboss.capture_headers = true
  config.eventboss.performance_monitoring = true
  config.eventboss.max_message_body_size = 4096 # 4KB limit
  
  # Exclude specific listener classes from Sentry reporting
  config.eventboss.excluded_listeners = [
    'HealthCheckListener',
    /Test.*Listener/,  # Regex patterns are supported
    SomeSpecificListener # Class references are supported
  ]
end

# The integration will automatically:
# 1. Add the Sentry error handler to Eventboss.configuration.error_handlers
# 2. Add the Sentry middleware to Eventboss.configuration.server_middleware
# 3. Enable distributed tracing between publishers and consumers
# 4. Create performance transactions and spans for job processing
# 5. Capture rich context about queues, events, and processing state
  end
end

# Configure Eventboss to use the enhanced Sentry integration
Eventboss.configure do |config|
  # Configure Sentry integration for Eventboss
  config.sentry_configuration.tap do |sentry|
    # Only report errors after all retries are exhausted
    sentry.report_after_retries = true
    
    # Capture message body in error context (be careful with sensitive data)
    sentry.capture_message_body = false  # Default: false for security
    
    # Capture message headers/attributes
    sentry.capture_message_headers = true  # Default: true
    
    # Enable trace propagation between publisher and consumer
    sentry.propagate_traces = true  # Default: true
    
    # Enable performance monitoring for job processing
    sentry.performance_monitoring = true  # Default: true
    
    # Exclude specific listener classes from Sentry reporting
    sentry.excluded_listeners = [
      'HealthCheckListener',
      /.*Test.*Listener/,  # Regex patterns supported
    ]
    
    # Maximum message body size to capture (in bytes)
    sentry.max_message_body_size = 4096  # Default: 4KB
  end

  # Add the enhanced Sentry middleware to wrap job execution with proper scope
  config.server_middleware.add(Eventboss::Middleware::SentryContext)

  # Configure error handlers - include the enhanced Sentry error handler
  config.error_handlers = [
    Eventboss::ErrorHandlers::Logger.new,
    Eventboss::ErrorHandlers::Sentry.new,  # Enhanced Sentry error handler
    Eventboss::ErrorHandlers::NonExistentQueueHandler.new
  ]
  
  # Add DB handlers if ActiveRecord is available
  if defined?(::ActiveRecord::StatementInvalid)
    config.error_handlers << Eventboss::ErrorHandlers::DbConnectionDropHandler.new
  end
  
  if defined?(::ActiveRecord::ConnectionNotEstablished)
    config.error_handlers << Eventboss::ErrorHandlers::DbConnectionNotEstablishedHandler.new
  end
end

# Example processor
class UserRegistrationProcessor
  def receive(payload)
    # Your processing logic here
    puts "Processing user registration: #{payload['user_id']}"
    
    # Simulate some work
    sleep 0.1
    
    # Uncomment to test error reporting:
    # raise StandardError.new("Registration failed") if payload['user_id'] == 'error'
  end
end

# The enhanced Sentry integration now provides:
#
# 1. Performance Monitoring:
#    - Transaction creation for each job processing with operation "queue.process"
#    - Span data with messaging information (queue, message ID, latency, retry count)
#    - Processing duration tracking and timing metrics
#    - HTTP status codes (200 for success, 500 for errors)
#    - Message size tracking
#
# 2. Distributed Tracing:
#    - Trace propagation headers automatically injected when publishing/sending messages
#    - Trace context extracted and continued when processing messages
#    - Connected traces across publisher and consumer services
#    - Baggage propagation support
#
# 3. Enhanced Error Context:
#    - Rich context about jobs, queues, and processing state
#    - Retry information and processing attempts (from SQS ApproximateReceiveCount)
#    - Message metadata and attributes
#    - Event-specific tags (event name, source app)
#    - Configurable context filtering for sensitive data
#
# 4. Advanced Configuration:
#    - Retry-aware error reporting (only report after all retries exhausted)
#    - Listener exclusion patterns (string, regex, or class matching)
#    - Message body and header capture controls
#    - Performance monitoring on/off switch
#    - Configurable message body size limits
#    - Trace propagation controls
#
# 5. Automatic Integration:
#    - Works with existing Eventboss error handlers
#    - Backward compatible with existing configurations
#    - Graceful degradation when Sentry is not available
#    - Middleware-based approach for clean separation

puts "Enhanced Eventboss Sentry integration configured!"
puts "Jobs will now run within Sentry transactions with proper context and error reporting."
