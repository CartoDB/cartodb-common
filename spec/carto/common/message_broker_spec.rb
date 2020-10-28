require 'spec_helper'
require 'carto/common/message_broker'

RSpec.describe Carto::Common::MessageBroker do
  describe '#initialize' do
    it 'gets its config from a MessageBroker::Config instance' do
      config = instance_double('Config', project_id: 'test-project-id')
      expect(Carto::Common::MessageBroker::Config).to receive(:instance).and_return(config)
      expect(Google::Cloud::Pubsub).to receive(:new)
      Carto::Common::MessageBroker.instance
    end
  end
end
