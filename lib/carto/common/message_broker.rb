require 'google/cloud/pubsub'
require 'singleton'

module Carto
  module Common

    class MessageBroker
      include Singleton

      def initialize()
        @config = Config.instance
        @project_id = @config.project_id
        @pubsub = Google::Cloud::Pubsub.new(project: @project_id)
        @topics = {}
        @subscriptions = {}
      end

      def get_topic(topic_name)
        @topics[topic_name] ||= Topic.new(@pubsub, project_id: @project_id, topic: topic_name)
      end

      def create_topic(topic_name)
        @pubsub.create_topic(topic_name.to_s) rescue Google::Cloud::AlreadyExistsError
        get_topic(topic_name)
      end

      def get_subscription(subscription_name)
        @subscriptions[subscription_name] ||= Subscription.new(@pubsub,
                                                               project_id: @project_id,
                                                               subscription_name: subscription_name)
      end

      class Config
        include Singleton

        attr_reader :project_id

        def initialize()
          if self.class.const_defined?(:Cartodb)
            config_module = Cartodb
          elsif self.class.const_defined?(:CartodbCentral)
            config_module = CartodbCentral
          else
            raise "Couldn't find a suitable config module"
          end

          config = config_module.config[:message_broker]
          @project_id = config['project_id']
        end
      end

      class Topic
        def initialize(pubsub, project_id:, topic:)
          @pubsub = pubsub
          @project_id = project_id
          @topic = @pubsub.topic("projects/#{@project_id}/topics/#{topic.to_s}")
        end

        def publish(event, payload)
          @topic.publish(payload.to_json, {event: event.to_s})
        end

        def create_subscription(subscription, options = {})
          # TODO this shall return a wrapping subscription object (?)
          @topic.create_subscription(subscription.to_s, options)
        rescue Google::Cloud::AlreadyExistsError
          nil
        end
      end

      class Subscription
        def initialize(pubsub, project_id:, subscription_name:)
          @pubsub = pubsub
          @project_id = project_id
          @subscription_name = subscription_name
          @subscription = @pubsub.get_subscription(subscription_name, project: project_id)
          @callbacks = {}
          @subscriber = nil
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
              message_callback.call(payload)
              received_message.ack!
            rescue StandardError => ex
              puts ex
              received_message.ack!
            end
          else
            puts "No callback registered for message #{message_type}"
            received_message.reject!
          end
        end

        def start(options = {})
          @subscriber = @subscription.listen(options, &:main_callback)
          @subscriber.start
        end

        def stop!
          @subscriber.stop!
        end
      end

    end
  end
end
