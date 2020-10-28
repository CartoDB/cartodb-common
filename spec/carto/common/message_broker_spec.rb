require 'spec_helper'
require 'carto/common/message_broker'


# See https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/dynamic-classes
class PubsubDouble
  include Google::Cloud::Pubsub
  def create_topic(*); super end
end

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
      expect(Carto::Common::MessageBroker::Topic).to receive(:new).with(pubsub, project_id: 'test-project-id', topic: 'dummy_topic')
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
      subscription = instance_double('Subscription')

      config = instance_double('Config', project_id: 'test-project-id')
      allow(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      allow(Google::Cloud::Pubsub).to receive(:new).with(project: 'test-project-id').and_return(pubsub)
      allow(Carto::Common::MessageBroker::Subscription).to receive(:new).with(pubsub, project_id: 'test-project-id', subscription_name: 'dummy_subscription')

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
    expect { Carto::Common::MessageBroker::Config.instance}.to raise_error "Couldn't find a suitable config module"
  end

end
