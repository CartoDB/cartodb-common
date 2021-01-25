require 'carto/common/message_broker'

RSpec.describe Carto::Common::MessageBroker::Config do
  let(:central_config_module) { Object.const_set(:CartodbCentral, Module.new) }

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
    central_config_module.define_singleton_method(:config) do
      { message_broker: { 'project_id' => 'test-project-id' } }
    end
    expect(described_class.instance.project_id).to eql 'test-project-id'
  end

  it 'raises an error if neither is defined' do
    expect { described_class.instance }.to raise_error "Couldn't find a suitable config module"
  end

  it 'allows to read other central_subscription_name config setting' do
    config_module = Object.const_set(:Cartodb, Module.new)
    config_module.define_singleton_method(:config) do
      {
        message_broker: {
          'project_id' => 'test-project-id',
          'central_subscription_name' => 'test-subscription-name'
        }
      }
    end
    expect(described_class.instance.central_subscription_name)
      .to eql 'test-subscription-name'
  end

  describe '#enabled?' do
    it 'returns false if not defined' do
      central_config_module.define_singleton_method(:config) do
        { message_broker: {} }
      end
      expect(described_class.instance.enabled?).to be false
    end

    it 'returns true when set to true' do
      central_config_module.define_singleton_method(:config) do
        { message_broker: { 'enabled' => true } }
      end
      expect(described_class.instance.enabled?).to be true
    end

    it 'returns false when set to false' do
      central_config_module.define_singleton_method(:config) do
        { message_broker: { 'enabled' => false } }
      end
      expect(described_class.instance.enabled?).to be false
    end
  end

  describe '#pubsub_project_service_account_name' do
    subject(:service_account_name) { described_class.instance.pubsub_project_service_account_name }

    let(:project_number) { 123_456_789 }

    before do
      central_config_module.define_singleton_method(:config) { { message_broker: { 'enabled' => true } } }
      pubsub_project = instance_double('Google::Cloud::ResourceManager::Project')
      allow(pubsub_project).to receive(:project_number).and_return(project_number)
      allow(described_class.instance).to receive(:pubsub_project).and_return(pubsub_project)
    end

    it 'returns the Service Account name of the current Pub/Sub project' do
      expect(service_account_name).to(
        eq("serviceAccount:service-#{project_number}@gcp-sa-pubsub.iam.gserviceaccount.com")
      )
    end
  end
end
