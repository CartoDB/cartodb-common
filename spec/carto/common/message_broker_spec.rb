require 'spec_helper'
require 'carto/common/message_broker'
require 'logger'

# See https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/dynamic-classes
# rubocop:disable Lint/UselessMethodDefinition
class PubsubDouble

  include Google::Cloud::Pubsub

  def create_topic(*)
    super
  end

  def get_topic(*)
    super
  end

  def get_subscription(*)
    super
  end

end

class PubsubMessageDouble < Google::Cloud::Pubsub::Message

  def ack!(*)
    super
  end

  def reject!(*)
    super
  end

end
# rubocop:enable Lint/UselessMethodDefinition

RSpec.describe Carto::Common::MessageBroker do
  before(:each) do
    Carto::Common::MessageBroker.instance_variable_set(:@singleton__instance__, nil)
  end

  describe '#initialize' do
    it 'gets its config from a MessageBroker::Config instance' do
      config = instance_double('Config', project_id: 'test-project-id')
      expect(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      expect(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id')

      expect(Carto::Common::MessageBroker.instance.project_id).to eql 'test-project-id'
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
      Carto::Common::MessageBroker.instance.get_topic(:dummy_topic)
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
      expect(Carto::Common::MessageBroker.instance.create_topic(:dummy_topic)).to eql topic
    end
  end

  describe '#get_subscription' do
    it 'creates a wrapper subscription object and returns it' do
      pubsub = instance_double('PubsubDouble')

      config = instance_double('Config', project_id: 'test-project-id')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)
      allow(Carto::Common::MessageBroker::Subscription).to receive(:new).with(pubsub,
                                                                              project_id: 'test-project-id',
                                                                              subscription_name: 'dummy_subscription')

      Carto::Common::MessageBroker.instance.get_subscription(:dummy_subscription)
    end
  end
end

RSpec.describe Carto::Common::MessageBroker::Config do
  before(:each) do
    Carto::Common::MessageBroker::Config.instance_variable_set(:@singleton__instance__, nil)
    Object.send(:remove_const, :Cartodb) if Object.constants.include?(:Cartodb)
    Object.send(:remove_const, :CartodbCentral) if Object.constants.include?(:CartodbCentral)
  end

  it 'uses Cartodb config module if it exists' do
    config_module = Object.const_set(:Cartodb, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: { 'project_id' => 'test-project-id' } }
    end
    expect(Carto::Common::MessageBroker::Config.instance.project_id).to eql 'test-project-id'
  end

  it 'uses CartodbCentral config module if it exists' do
    config_module = Object.const_set(:CartodbCentral, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: { 'project_id' => 'test-project-id' } }
    end
    expect(Carto::Common::MessageBroker::Config.instance.project_id).to eql 'test-project-id'
  end

  it 'raises an error if neither is defined' do
    expect { Carto::Common::MessageBroker::Config.instance }.to raise_error "Couldn't find a suitable config module"
  end

  it 'allows to read other central_commands_subscription config setting' do
    config_module = Object.const_set(:Cartodb, Module.new)
    config_module.define_singleton_method(:config) do
      {
        message_broker: {
          'project_id' => 'test-project-id',
          'central_commands_subscription' => 'test-subscription-name'
        }
      }
    end
    expect(described_class.instance.central_commands_subscription)
      .to eql 'test-subscription-name'
  end

  it 'enabled? returns false if not defined' do
    config_module = Object.const_set(:CartodbCentral, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: {} }
    end
    expect(Carto::Common::MessageBroker::Config.instance.enabled?).to be false
  end

  it 'enabled? returns true when set to true' do
    config_module = Object.const_set(:CartodbCentral, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: { 'enabled' => true } }
    end
    expect(Carto::Common::MessageBroker::Config.instance.enabled?).to be true
  end

  it 'enabled? returns false when set to false' do
    config_module = Object.const_set(:CartodbCentral, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: { 'enabled' => false } }
    end
    expect(Carto::Common::MessageBroker::Config.instance.enabled?).to be false
  end
end

RSpec.describe Carto::Common::MessageBroker::Topic do
  describe '#initialize' do
    it 'delegates on the pubsub instance to get the topic to be used' do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic')

      my_topic = Carto::Common::MessageBroker::Topic.new(pubsub, project_id: 'test-project-id', topic: :my_topic)
      expect(my_topic.project_id).to eql 'test-project-id'
      expect(my_topic.topic_name).to eql 'my_topic'
    end
  end

  describe '#publish' do
    it 'delegates on the pubsub topic instance to publish events' do
      pubsub = instance_double('PubsubDouble')
      pubsub_topic = instance_double('Google::Cloud::Pubsub::Topic')
      allow(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic').and_return(pubsub_topic)
      my_topic = Carto::Common::MessageBroker::Topic.new(pubsub, project_id: 'test-project-id', topic: :my_topic)

      expect(pubsub_topic).to receive(:publish).with('{}', { event: 'test_event' })
      my_topic.publish(:test_event, {})
    end
  end

  describe '#create_subscription' do
    it 'delegates on the pubsub topic instance to create subscriptions' do
      pubsub = instance_double('PubsubDouble')
      pubsub_topic = instance_double('Google::Cloud::Pubsub::Topic')
      allow(pubsub).to receive(:get_topic).with('projects/test-project-id/topics/my_topic').and_return(pubsub_topic)
      my_topic = Carto::Common::MessageBroker::Topic.new(pubsub, project_id: 'test-project-id', topic: :my_topic)

      expect(pubsub_topic).to receive(:create_subscription).with('my_subscription', {})
      my_topic.create_subscription('my_subscription')
    end
  end
end

RSpec.describe Carto::Common::MessageBroker::Subscription do
  let(:logger) { instance_double('Logger') }

  describe '#initialize' do
    it 'delegates on the pubsub object to get the subscription' do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      Carto::Common::MessageBroker::Subscription.new(pubsub,
                                                     project_id: 'test-project-id',
                                                     subscription_name: 'test_subscription',
                                                     logger: logger)
    end
  end

  describe '#main_callback' do
    it 'dispatches messages to a registered callback' do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      subscription = Carto::Common::MessageBroker::Subscription.new(pubsub,
                                                                    project_id: 'test-project-id',
                                                                    subscription_name: 'test_subscription',
                                                                    logger: logger)
      subscription.register_callback(:dummy_command) do |_payload|
        'success!'
      end

      message = instance_double('PubsubMessageDouble')
      expect(message).to receive(:data).and_return('{}')
      expect(message).to receive(:attributes).and_return({ 'event' => 'dummy_command' })
      expect(message).to receive(:ack!)
      expect(subscription.main_callback(message)).to eql 'success!'
    end

    it "rejects a message if there's no callback registered for it" do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      subscription = Carto::Common::MessageBroker::Subscription.new(pubsub,
                                                                    project_id: 'test-project-id',
                                                                    subscription_name: 'test_subscription',
                                                                    logger: logger)

      message = instance_double('PubsubMessageDouble')
      expect(logger).to receive(:warn)
      expect(message).to receive(:attributes).and_return({ 'event' => 'dummy_command' })
      expect(message).to receive(:reject!)
      expect(subscription.main_callback(message)).to eql nil
    end

    it "logs an error if there's an unexpected exception within the callback, but acknowledges the message" do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      subscription = Carto::Common::MessageBroker::Subscription.new(pubsub,
                                                                    project_id: 'test-project-id',
                                                                    subscription_name: 'test_subscription',
                                                                    logger: logger)
      subscription.register_callback(:dummy_command) do
        raise 'unexpected exception'
      end

      message = instance_double('PubsubMessageDouble')
      expect(message).to receive(:data).and_return('{}')
      expect(message).to receive(:attributes).and_return({ 'event' => 'dummy_command' })
      expect(logger).to receive(:error)
      expect(message).to receive(:ack!)
      expect(subscription.main_callback(message)).to eql nil
    end
  end
end
