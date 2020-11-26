require 'carto/common/message_broker'

RSpec.describe Carto::Common::MessageBroker::Config do
  before do
    described_class.instance_variable_set(:@singleton__instance__, nil)
    Object.send(:remove_const, :Cartodb) if Object.constants.include?(:Cartodb)
    Object.send(:remove_const, :CartodbCentral) if Object.constants.include?(:CartodbCentral)
  end

  it 'uses Cartodb config module if it exists' do
    config_module = Object.const_set(:Cartodb, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: { 'project_id' => 'test-project-id' } }
    end
    expect(described_class.instance.project_id).to eql 'test-project-id'
  end

  it 'uses CartodbCentral config module if it exists' do
    config_module = Object.const_set(:CartodbCentral, Module.new)
    config_module.define_singleton_method(:config) do
      { message_broker: { 'project_id' => 'test-project-id' } }
    end
    expect(described_class.instance.project_id).to eql 'test-project-id'
  end

  it 'raises an error if neither is defined' do
    expect { described_class.instance }.to raise_error "Couldn't find a suitable config module"
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

  describe '#enabled?' do
    it 'returns false if not defined' do
      config_module = Object.const_set(:CartodbCentral, Module.new)
      config_module.define_singleton_method(:config) do
        { message_broker: {} }
      end
      expect(described_class.instance.enabled?).to be false
    end

    it 'returns true when set to true' do
      config_module = Object.const_set(:CartodbCentral, Module.new)
      config_module.define_singleton_method(:config) do
        { message_broker: { 'enabled' => true } }
      end
      expect(described_class.instance.enabled?).to be true
    end

    it 'returns false when set to false' do
      config_module = Object.const_set(:CartodbCentral, Module.new)
      config_module.define_singleton_method(:config) do
        { message_broker: { 'enabled' => false } }
      end
      expect(described_class.instance.enabled?).to be false
    end
  end
end
