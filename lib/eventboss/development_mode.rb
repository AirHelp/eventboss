# frozen_string_literal: true

module Eventboss
  module DevelopmentMode
    extend Logging

    class << self
      def setup_infrastructure(queues)
        sns_client = Eventboss.configuration.sns_client
        sqs_client = Eventboss.configuration.sqs_client

        queues.each do |queue, listener|
          topic_name = Eventboss::Topic.build_name(**listener.options)
          logger.info('development-mode') { "Creating topic #{topic_name}..." }
          topic = sns_client.create_topic(name: topic_name)

          logger.info('development-mode') { "Creating queue #{queue.name}..." }
          sqs_client.create_queue(queue_name: queue.name)

          logger.info('development-mode') { "Setting up queue #{queue.name} policy..." }
          policy = queue_policy(queue.arn, topic.topic_arn)
          sqs_client.set_queue_attributes(queue_url: queue.url, attributes: { Policy: policy.to_json })

          logger.info('development-mode') { "Creating subscription for topic #{topic.topic_arn} and #{queue.arn}..." }
          sns_client.create_subscription(topic_arn: topic.topic_arn, queue_arn: queue.arn)
        end
      end

      def queue_policy(queue_arn, topic_arn)
        {
          "Version": "2012-10-17",
          "Statement": [{
            "Sid": "queue-policy-#{queue_arn}-#{topic_arn}",
            "Effect": "Allow",
            "Principal": "*",
            "Action": ["SQS:SendMessage"],
            "Resource": "#{queue_arn}",
            "Condition": {
              "ArnEquals": {
                "aws:SourceArn": "#{topic_arn}"
              }
            }
          }]
        }
      end
    end
  end
end
