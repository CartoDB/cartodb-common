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
      pubsub = instance_double('Google::Cloud::Pubsub')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)
      expect(Carto::Common::MessageBroker::Topic).to receive(:new).with(pubsub,
                                                                        project_id: 'test-project-id',
                                                                        topic: 'dummy_topic')
      message_broker.get_topic(:dummy_topic)
    end
  end

  describe '#create_topic' do
    it 'creates and returns a topic' do
      config = instance_double('Config', project_id: 'test-project-id')
      pubsub = instance_double('PubsubDouble')
      topic = instance_double('Topic')

      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)
      expect(pubsub).to receive(:create_topic).with('dummy_topic')
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
          hash_including(project_id: 'test-project-id', subscription_name: 'dummy_subscription')
        )
      )

      message_broker.get_subscription(:dummy_subscription)
    end
  end
end
