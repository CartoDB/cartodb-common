require 'google/cloud/pubsub'
require 'singleton'

module Carto
  module Common

    module MessageBrokerPrefix

      PREFIX = 'broker_'.freeze

      def pubsub_prefixed_name(input_symbol_or_string)
        PREFIX + input_symbol_or_string.to_s
      end

    end

    class MessageBroker

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
        @topics[topic_name] ||= Topic.new(@pubsub, project_id: @project_id, topic_name: topic_name)
      end

      def create_topic(topic)
        topic_name = pubsub_prefixed_name(topic)
        begin
          @pubsub.create_topic(topic_name)
        rescue Google::Cloud::AlreadyExistsError
          nil
        end
        get_topic(topic_name)
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
                    :central_commands_subscription

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
          @central_commands_subscription = config['central_commands_subscription']
          @enabled = config['enabled']
        end

        def enabled?
          @enabled || false
        end

      end

      class Topic

        include MessageBrokerPrefix

        attr_reader :project_id, :topic_name

        def initialize(pubsub, project_id:, topic_name:)
          @pubsub = pubsub
          @project_id = project_id
          @topic_name = topic_name
          @topic = @pubsub.get_topic("projects/#{@project_id}/topics/#{@topic_name}")
        end

        def publish(event, payload)
          @topic.publish(payload.to_json, { event: event.to_s })
        end

        def create_subscription(subscription, options = {})
          # TODO: this shall return a wrapping subscription object (?)
          subscription_name = pubsub_prefixed_name(subscription)
          @topic.create_subscription(subscription_name, options)
        rescue Google::Cloud::AlreadyExistsError
          nil
        end

        def delete
          @topic.delete
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
          message_type = received_message.attributes['event'].to_sym
          message_callback = @callbacks[message_type]
          if message_callback
            begin
              payload = JSON.parse(received_message.data).with_indifferent_access
              ret = message_callback.call(payload)
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
              received_message.ack!
            end
          else
            logger.warn(message: 'No callback registered for message',
                        subscription_name: @subscription_name,
                        message_type: message_type)
            received_message.reject!
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
