require 'carto/common/message_broker'

RSpec.describe Carto::Common::MessageBroker::Topic do
  describe '#initialize' do
    it 'delegates on the pubsub instance to get the topic to be used' do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic')

      my_topic = described_class.new(pubsub, project_id: 'test-project-id', topic_name: 'my_topic')
      expect(my_topic.project_id).to eql 'test-project-id'
      expect(my_topic.topic_name).to eql 'my_topic'
    end
  end

  describe '#publish' do
    let(:request_id) { SecureRandom.hex }
    let(:pubsub_topic) { instance_double('Google::Cloud::Pubsub::Topic') }
    let(:pubsub) do
      double = instance_double('PubsubDouble')
      allow(double).to receive(:get_topic).with('projects/test-project-id/topics/my_topic').and_return(pubsub_topic)
      double
    end
    let(:my_topic) { described_class.new(pubsub, project_id: 'test-project-id', topic_name: 'my_topic') }
    let(:my_topic_with_token) do
      described_class.new(pubsub,
                          project_id: 'test-project-id',
                          topic_name: 'my_topic',
                          publisher_validation_token: 'my-secret-token')
    end

    it 'delegates on the pubsub topic instance to publish events' do
      expect(pubsub_topic).to receive(:publish).with('{}', { event: 'test_event' })
      my_topic.publish(:test_event, {})
    end

    it 'includes the request_id in the payload if available' do
      expect(pubsub_topic).to receive(:publish).with("{\"request_id\":\"#{request_id}\"}", { event: 'test_event' })

      Carto::Common::CurrentRequest.with_request_id(request_id) do
        my_topic.publish(:test_event, {})
      end
    end

    it 'does not override payload request_id if already set' do
      expect(pubsub_topic).to receive(:publish).with("{\"request_id\":\"#{request_id}\"}", { event: 'test_event' })
      my_topic.publish(:test_event, { request_id: request_id })
    end

    it 'adds the publisher_validation_token to the attributes when passed' do
      expect(pubsub_topic).to receive(:publish).with("{\"request_id\":\"#{request_id}\"}", {
                                                       event: 'test_event',
                                                       publisher_validation_token: 'my-secret-token'
                                                     })
      my_topic_with_token.publish(:test_event, { request_id: request_id })
    end
  end

  describe '#create_subscription' do
    let(:pubsub) do
      pubsub = instance_double('PubsubDouble')
      allow(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic').and_return(pubsub_topic)
      allow(pubsub).to receive(:get_subscription).with('broker_my_subscription', project: 'test-project-id')
      allow(pubsub_subscription).to receive(:name)
      pubsub
    end
    let(:pubsub_topic) { instance_double('Google::Cloud::Pubsub::Topic') }
    let(:pubsub_subscription) { instance_double('Google::Cloud::Pubsub::Subscription') }
    let(:my_topic) { described_class.new(pubsub, project_id: 'test-project-id', topic_name: 'my_topic') }

    it 'delegates on the pubsub topic instance to create subscriptions' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription', any_args)
                                                           .and_return(pubsub_subscription)
      my_topic.create_subscription(:my_subscription)
    end

    it 'returns a wrapping subscription object' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription', any_args)
                                                           .and_return(pubsub_subscription)
      expect(my_topic.create_subscription(:my_subscription)).to be_a(Carto::Common::MessageBroker::Subscription)
    end

    it 'creates the subscription with an acknowledge deadline of 5 minutes' do
      expect(pubsub_topic).to(
        receive(:create_subscription).with('broker_my_subscription', hash_including(deadline: 300))
                                     .and_return(pubsub_subscription)
      )
      my_topic.create_subscription(:my_subscription)
    end

    it 'adds a retry policy of minimum 10 seconds and maximum 10 minutes between retries' do
      expect(pubsub_topic).to receive(:create_subscription) do |_subscription_name, options|
        expect(options[:retry_policy].minimum_backoff).to eq(10)
        expect(options[:retry_policy].maximum_backoff).to eq(600)
      end.and_return(pubsub_subscription)
      my_topic.create_subscription(:my_subscription)
    end

    context 'when dead letter configuration is specified' do
      before do
        allow(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/broker_my-dead-letter-topic')
                                            .and_return(pubsub_topic)
      end

      it 'propagates the settings to the inner Pub/Sub client' do
        expect(pubsub_topic).to(
          receive(:create_subscription).with(
            'broker_my_subscription',
            hash_including(dead_letter_topic: anything, dead_letter_max_delivery_attempts: 100)
          )
        ).and_return(pubsub_subscription)

        my_topic.create_subscription(
          :my_subscription,
          dead_letter_topic_name: 'my-dead-letter-topic',
          dead_letter_max_delivery_attempts: 100
        )
      end
    end
  end
end
