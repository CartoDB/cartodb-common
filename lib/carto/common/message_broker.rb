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
        end

        def listen(options = {}, &block)
          # NOTE this returns a plain Google::Cloud::PubSub::Subscriber
          @subscription.listen(options, &block)
        end
      end

    end
  end
end
