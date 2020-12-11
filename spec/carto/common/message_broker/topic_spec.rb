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
    it 'delegates on the pubsub topic instance to publish events' do
      pubsub = instance_double('PubsubDouble')
      pubsub_topic = instance_double('Google::Cloud::Pubsub::Topic')
      allow(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic').and_return(pubsub_topic)
      my_topic = described_class.new(pubsub, project_id: 'test-project-id', topic_name: 'my_topic')

      expect(pubsub_topic).to receive(:publish).with('{}', { event: 'test_event' })
      my_topic.publish(:test_event, {})
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
  end
end
