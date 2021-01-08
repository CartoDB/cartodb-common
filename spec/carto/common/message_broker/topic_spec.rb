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
  end

  describe '#create_subscription' do
    let(:pubsub) do
      pubsub = instance_double('PubsubDouble')
      allow(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic').and_return(pubsub_topic)
      allow(pubsub).to receive(:get_subscription).with('broker_my_subscription', project: 'test-project-id')
      pubsub
    end
    let(:pubsub_topic) { instance_double('Google::Cloud::Pubsub::Topic') }
    let(:my_topic) { described_class.new(pubsub, project_id: 'test-project-id', topic_name: 'my_topic') }

    it 'delegates on the pubsub topic instance to create subscriptions' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription', any_args)
      my_topic.create_subscription(:my_subscription)
    end

    it 'returns a wrapping subscription object' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription', any_args)
      expect(my_topic.create_subscription(:my_subscription)).to be_a(Carto::Common::MessageBroker::Subscription)
    end

    it 'creates the subscription with an acknowledge deadline of 5 minutes' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription',
                                                                 hash_including(deadline: 300))
      my_topic.create_subscription(:my_subscription)
    end

    it 'default deadline can be overridden' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription',
                                                                 hash_including(deadline: 60))
      my_topic.create_subscription(:my_subscription, deadline: 60)
    end

    it 'adds a retry policy of minimum 10 seconds and maximum 10 minutes between retries' do
      expect(pubsub_topic).to receive(:create_subscription) do |_subscription_name, options|
        expect(options[:retry_policy].minimum_backoff).to eq(10)
        expect(options[:retry_policy].maximum_backoff).to eq(600)
      end
      my_topic.create_subscription(:my_subscription)
    end

    it 'may include non-default options such as the push endpoint' do
      expect(pubsub_topic).to receive(:create_subscription).with('broker_my_subscription',
                                                                 hash_including(endpoint: 'https://example.com/push'))
      my_topic.create_subscription(:my_subscription, endpoint: 'https://example.com/push')
    end
  end
end
