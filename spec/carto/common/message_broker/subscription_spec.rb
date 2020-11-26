require 'carto/common/message_broker'

RSpec.describe Carto::Common::MessageBroker::Subscription do
  let(:logger) { instance_double('Logger') }

  describe '#initialize' do
    it 'delegates on the pubsub object to get the subscription' do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      described_class.new(
        pubsub,
        project_id: 'test-project-id',
        subscription_name: 'test_subscription',
        logger: logger
      )
    end
  end

  describe '#main_callback' do
    it 'dispatches messages to a registered callback' do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      subscription = described_class.new(
        pubsub,
        project_id: 'test-project-id',
        subscription_name: 'test_subscription',
        logger: logger
      )
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

      subscription = described_class.new(
        pubsub,
        project_id: 'test-project-id',
        subscription_name: 'test_subscription',
        logger: logger
      )

      message = instance_double('PubsubMessageDouble')
      expect(logger).to receive(:warn)
      expect(message).to receive(:attributes).and_return({ 'event' => 'dummy_command' })
      expect(message).to receive(:reject!)
      expect(subscription.main_callback(message)).to be_nil
    end

    it "logs an error if there's an unexpected exception within the callback, but acknowledges the message" do
      pubsub = instance_double('PubsubDouble')
      expect(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')

      subscription = described_class.new(
        pubsub,
        project_id: 'test-project-id',
        subscription_name: 'test_subscription',
        logger: logger
      )
      subscription.register_callback(:dummy_command) do
        raise 'unexpected exception'
      end

      message = instance_double('PubsubMessageDouble')
      expect(message).to receive(:data).and_return('{}')
      expect(message).to receive(:attributes).and_return({ 'event' => 'dummy_command' })
      expect(logger).to receive(:error)
      expect(message).to receive(:ack!)
      expect(subscription.main_callback(message)).to be_nil
    end
  end
end
