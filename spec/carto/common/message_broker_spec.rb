require 'spec_helper'
require 'carto/common/message_broker'
require 'logger'

RSpec.describe Carto::Common::MessageBroker do
  subject(:message_broker) { described_class.new(logger: logger) }

  let(:logger) { ::Logger.new($stdout) }

  before do
    described_class.instance_variable_set(:@singleton__instance__, nil)
  end

  describe '#initialize' do
    it 'gets its config from a MessageBroker::Config instance' do
      config = instance_double('Config', project_id: 'test-project-id')
      expect(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      expect(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id')

      expect(message_broker.project_id).to eql 'test-project-id'
    end
  end

  describe '#get_topic' do
    it 'gets a topic configured with the intended pubsub instance, project_id and topic' do
      config = instance_double('Config', project_id: 'test-project-id')
      allow(config).to receive(:publisher_validation_token).and_return('some-cloud-secret-token')
      pubsub = instance_double('Google::Cloud::Pubsub')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)
      expect(Carto::Common::MessageBroker::Topic).to(
        receive(:new).with(pubsub, hash_including(project_id: 'test-project-id', topic_name: 'broker_dummy_topic'))
      )
      message_broker.get_topic(:dummy_topic)
    end

    it 'gets its token from configuration' do
      config = instance_double('Config', project_id: 'test-project-id')
      allow(config).to receive(:publisher_validation_token).and_return('some-cloud-secret-token')
      pubsub = instance_double('PubsubDouble')
      allow(pubsub).to receive(:get_topic)
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).and_return(pubsub)
      expect(message_broker.get_topic(:dummy_topic).publisher_validation_token).to eql 'some-cloud-secret-token'
    end
  end

  describe '#create_topic' do
    let(:config) { instance_double('Config', project_id: 'test-project-id') }
    let(:pubsub) { instance_double('PubsubDouble') }
    let(:topic) { instance_double('Topic') }
    let(:pubsub_topic) { instance_double('Google::Cloud::Pubsub::Topic') }

    before { allow(pubsub_topic).to receive(:name) }

    it 'creates and returns a topic' do
      allow(config).to receive(:publisher_validation_token).and_return('some-cloud-secret-token')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)

      expect(pubsub).to receive(:create_topic).with('broker_dummy_topic').and_return(pubsub_topic)
      expect(Carto::Common::MessageBroker::Topic).to receive(:new).and_return(topic)
      expect(message_broker.create_topic(:dummy_topic)).to eql topic
    end
  end

  describe '#get_subscription' do
    it 'creates a wrapper subscription object and returns it' do
      pubsub = instance_double('PubsubDouble')

      config = instance_double('Config', project_id: 'test-project-id')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)
      allow(Carto::Common::MessageBroker::Subscription).to(
        receive(:new).with(
          pubsub,
          hash_including(project_id: 'test-project-id', subscription_name: 'broker_dummy_subscription')
        )
      )

      message_broker.get_subscription(:dummy_subscription)
    end

    it 'propagates the specified logger to the subscriptions' do
      gcloud_subscriber = instance_double(Google::Cloud::PubSub::Subscriber)
      allow(gcloud_subscriber).to receive(:start)

      gcloud_subscription = instance_double(Google::Cloud::PubSub::Subscription)
      allow(gcloud_subscription).to receive(:listen).and_return(gcloud_subscriber)

      pubsub = instance_double('PubsubDouble')
      allow(pubsub).to receive(:get_subscription).and_return(gcloud_subscription)

      config = instance_double('Config', project_id: 'test-project-id')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)

      subscription = message_broker.get_subscription(:dummy_subscription)

      expect(logger).to receive(:info).with(hash_including(message: 'Starting message processing in subscriber'))

      subscription.start
    end
  end
end
