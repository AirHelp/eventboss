# Eventboss

[![Gem Version](https://badge.fury.io/rb/eventboss.svg)](https://badge.fury.io/rb/eventboss)

AWS based Pub/Sub implementation in Ruby.

## Features

* [x] language agnostic (ruby, js http://github.com/AirHelp/eventboss-js)
* [x] fluent interface
* [x] multithread polling (multi polling strategy)
* [x] generic queues (multiple apps sending the same event)
* [x] postponing jobs
* [x] automatic serialization/deserialization
* [x] batch sending (SQS one-to-one)
* [x] support multiple environments in the same AWS account
* [x] pluggable error handlers (airbrake, newrelic)
* [x] utility tasks (deadletter reload)
* [x] localstack compatible
* [x] rails support (preloads rails environment)
* [ ] terraform pub/sub scripts
* [ ] development mode (creates missing SNS/SQS on the fly)
* [ ] alternative infrastructure (redis?, kafka?)
* [ ] message compression
* [ ] alternative serialization (protobuf)
* [ ] subscription filtering
* [ ] fifo queues support

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventboss'
```

## Usage

Run the listener by:
```
bundle exec eventboss
```
it will read conf values from ENV variables in configuration sections.

### Broadcasting events:

```ruby
publisher = Eventboss.publisher(event_name)
publisher.publish(payload)
```

### Unicasting events in batches: (via SQS)

```ruby
sender = Eventboss.sender(event_name, destination_app)
sender.send_batch([payload1, payload2])
```

Receiving events via listeners:

```ruby
class AnyName
  include Eventboss::Listener
  eventboss_options source_app: 'src_app_name', event_name: 'my_event'

  def receive(payload)
  end
end
```


## Configuration

By default, no exception will be raised when publisher configuration is missing (`eventboss_region`,
`eventboss_account_id`, `eventboss_app_name`). This can lead to false-positive specs, app not working without exceptions on dev/stg/prod environment. It's strongly advised to set `raise_on_missing_configuration` to true.

Using `.configure`:

```ruby
Eventboss.configure do |config|
  config.raise_on_missing_configuration = true
  config.eventboss_account_id = 1234567
  config.eventboss_app_name = name
  config.eventboss_region = aws_region
  config.concurrency = 10
  # when using custom clients like localstack
  config.sns_client = client # Custom SNS Client can be used, i.e. to use local mock, see: https://github.com/phstc/shoryuken/wiki/Using-a-local-mock-SQS-server
  config.sqs_client = Aws::SQS::Client.new(endpoint: 'http://localstack:4576', region: 'us-east-1', credentials: Aws::Credentials.new('fake', 'fake'))
end
```

Using ENVs:

```
EVENTBUS_ACCOUNT_ID=12345676
EVENTBUS_APP_NAME=application_name
EVENTBUS_ENV=env_name # production/staging/test
EVENTBUS_REGION=aws_region # i.e. eu-west-1
EVENTBUS_CONCURRENCY=10 # default is 25

AWS_SNS_ENDPOINT=http://localhost:4575 # when using with localstack
AWS_SQS_ENDPOINT=http://localhost:4576 # when using with localstack
```

Be aware that `eventbus:deadletter:reload` rake task won't load your configuration if you are not using ENVs
 in non Rails app, although to make it work you can extend your `Rakefile` with:

```ruby
load File.join(Gem::Specification.find_by_name('eventboss').gem_dir, 'lib', 'tasks', 'eventboss.rake')

task :environment do
  # Load your environment
  # Example:
  # require_relative 'config/application'
end

task 'eventboss:deadletter:reload': :environment
```

### Logging and error handling
To have more verbose logging, set `log_level` in configuration (default is `info`).

Logger is used as default error handler. There is Airbrake handler available, to use it ensure you have `airbrake` or `airbrake-ruby` gem and add it to error handlers stack:

```ruby
Eventboss.configure do |config|
  config.error_handlers << Eventboss::ErrorHandlers::Airbrake.new
end
```

## Topics & Queues naming convention

The SNSes should be name in the following pattern:
```
eventboss-{src_app_name}-{event_name}-{environment}
```

i.e.
```
eventboss-srcapp-transaction_change-staging
```

The corresponding SQSes should be name like:
```
{dest_app_name}-eventboss-{src_app_name}-{event_name}-{environment}
{dest_app_name}-eventboss-{src_app_name}-{event_name}-{environment}-deadletter
```
i.e.
```
destapp-eventboss-srcapp-transaction_change-staging
destapp-eventboss-srcapp-transaction_change-staging-deadletter
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/AirHelp/eventboss.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
