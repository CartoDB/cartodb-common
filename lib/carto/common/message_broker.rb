require 'google/cloud/pubsub'
require 'google/cloud/pubsub/retry_policy'
require 'singleton'
require_relative 'current_request'
require_relative './helpers/environment_helper'

module Carto
  module Common

    module MessageBrokerPrefix

      PREFIX = 'broker_'.freeze

      def pubsub_prefixed_name(input_symbol_or_string)
        PREFIX + input_symbol_or_string.to_s
      end

    end

    class MessageBroker

      SUBSCRIPTION_ACK_DEADLINE_SECONDS = 300
      SUBSCRIPTION_RETRY_POLICY = Google::Cloud::PubSub::RetryPolicy.new(minimum_backoff: 10,
                                                                         maximum_backoff: 600)

      include MessageBrokerPrefix

      attr_reader :logger, :project_id

      def initialize(logger:)
        @config = Config.instance
        @project_id = @config.project_id
        @pubsub = Google::Cloud::Pubsub.new(project: @project_id)
        @topics = {}
        @subscriptions = {}
        @logger = logger || ::Logger.new($stdout)
      end

      def get_topic(topic)
        topic_name = pubsub_prefixed_name(topic)
        @topics[topic_name] ||= Topic.new(
          @pubsub,
          project_id: @project_id,
          topic_name: topic_name,
          logger: logger,
          publisher_validation_token: @config.publisher_validation_token
        )
      end

      def create_topic(topic)
        topic_name = pubsub_prefixed_name(topic)
        begin
          @pubsub.create_topic(topic_name)
        rescue Google::Cloud::AlreadyExistsError
          nil
        end
        get_topic(topic)
      end

      def get_subscription(subscription)
        subscription_name = pubsub_prefixed_name(subscription)
        @subscriptions[subscription] ||= Subscription.new(@pubsub,
                                                          project_id: @project_id,
                                                          subscription_name: subscription_name,
                                                          logger: logger)
      end

      class Config

        include Singleton

        attr_reader :project_id,
                    :central_subscription_name,
                    :metrics_subscription_name,
                    :publisher_validation_token

        def initialize
          if self.class.const_defined?(:Cartodb)
            config_module = Cartodb
          elsif self.class.const_defined?(:CartodbCentral)
            config_module = CartodbCentral
          else
            raise "Couldn't find a suitable config module"
          end

          config = config_module.config[:message_broker]
          @project_id = config['project_id']
          @central_subscription_name = config['central_subscription_name']
          @metrics_subscription_name = config['metrics_subscription_name']
          @publisher_validation_token = config['publisher_validation_token']
          @enabled = config['enabled']
        end

        def enabled?
          @enabled || false
        end

      end

      class Topic

        include MessageBrokerPrefix
        include ::EnvironmentHelper

        attr_reader :logger, :project_id, :topic_name, :publisher_validation_token

        def initialize(pubsub, project_id:, topic_name:, logger: nil, publisher_validation_token: nil)
          @pubsub = pubsub
          @project_id = project_id
          @topic_name = topic_name
          @topic = @pubsub.get_topic("projects/#{@project_id}/topics/#{@topic_name}")
          @logger = logger || ::Logger.new($stdout)
          @publisher_validation_token = publisher_validation_token
        end

        def publish(event, payload)
          merge_request_id!(payload)
          attributes = { event: event.to_s }
          attributes[:publisher_validation_token] = publisher_validation_token if publisher_validation_token
          result = @topic.publish(
            payload.to_json,
            attributes
          )
          log_published_event(event, payload)
          result
        end

        def create_subscription(subscription)
          begin
            subscription_name = pubsub_prefixed_name(subscription)
            @topic.create_subscription(subscription_name,
                                       deadline: SUBSCRIPTION_ACK_DEADLINE_SECONDS,
                                       retry_policy: SUBSCRIPTION_RETRY_POLICY)
          rescue Google::Cloud::AlreadyExistsError
            nil
          end
          Subscription.new(@pubsub,
                           project_id: @project_id,
                           subscription_name: subscription_name)
        end

        def delete
          @topic.delete
        end

        private

        def log_published_event(event, payload)
          log_payload = {
            message: 'Publishing event',
            event: event,
            request_id: Carto::Common::CurrentRequest.request_id
          }
          log_payload[:payload] = payload if development_environment? || staging_environment?
          logger.info(log_payload)
        end

        def merge_request_id!(payload)
          request_id = Carto::Common::CurrentRequest.request_id

          if payload.is_a?(Hash) && payload[:request_id].blank? && request_id
            payload.merge!(request_id: Carto::Common::CurrentRequest.request_id)
          end
        end

      end

      class Message

        attr_reader :payload,
                    :request_id,
                    :publisher_validation_token

        def initialize(payload: {}, request_id: nil, publisher_validation_token: nil)
          @payload = payload.with_indifferent_access
          @request_id = request_id
          @publisher_validation_token = publisher_validation_token
        end

      end

      class Subscription

        attr_reader :logger

        def initialize(pubsub, project_id:, subscription_name:, logger: nil)
          @pubsub = pubsub
          @project_id = project_id
          @subscription_name = subscription_name
          @subscription = @pubsub.get_subscription(subscription_name, project: project_id)
          @callbacks = {}
          @subscriber = nil
          @logger = logger || ::Logger.new($stdout)
        end

        def delete
          @subscription.delete
        end

        def register_callback(message_type, &block)
          @callbacks[message_type.to_sym] = block
        end

        def main_callback(received_message)
          attributes = received_message.attributes
          message_type = attributes['event'].to_sym
          message_callback = @callbacks[message_type]
          if message_callback
            begin
              payload = JSON.parse(received_message.data)
              request_id = payload.delete('request_id')
              message = Message.new(
                payload: payload,
                request_id: request_id,
                publisher_validation_token: attributes['publisher_validation_token']
              )
              ret = message_callback.call(message)
              received_message.ack!
              ret
            rescue StandardError => e
              logger.error(message: 'Error in message processing callback',
                           exception: {
                             class: e.class.name,
                             message: e.message,
                             backtrace_hint: e.backtrace&.take(5)
                           },
                           subscription_name: @subscription_name,
                           message_type: message_type)
              # Make the message available for redelivery
              received_message.reject!
            end
          else
            logger.error(message: 'No callback registered for message',
                         subscription_name: @subscription_name,
                         message_type: message_type)
            received_message.ack!
          end
        end

        def start(options = {})
          logger.info(message: 'Starting message processing in subscriber',
                      subscription_name: @subscription_name)
          @subscriber = @subscription.listen(options, &method(:main_callback))
          @subscriber.start
        end

        def stop!
          logger.info(message: 'Stopping message processing in subscriber',
                      subscription_name: @subscription_name)
          @subscriber.stop!
        end

      end

    end

  end
end
