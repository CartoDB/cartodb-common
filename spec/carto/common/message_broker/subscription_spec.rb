require 'carto/common/message_broker'

RSpec.describe Carto::Common::MessageBroker::Subscription do
  let(:logger) { instance_double('Logger') }
  let(:message) { instance_double('PubsubMessageDouble') }
  let(:pubsub) { instance_double('PubsubDouble') }
  let(:subscription) do
    described_class.new(
      pubsub,
      project_id: 'test-project-id',
      subscription_name: 'test_subscription',
      logger: logger
    )
  end

  before do
    allow(pubsub).to receive(:get_subscription).with('test_subscription', project: 'test-project-id')
    allow(message).to receive(:ack!)
    allow(message).to receive(:attributes).and_return({ 'event' => 'dummy_command' })
    allow(message).to receive(:data).and_return('{}')
  end

  describe '#initialize' do
    it 'delegates on the pubsub object to get the subscription' do
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
      subscription.register_callback(:dummy_command) do |message|
        if message.payload[:username] == 'coyote'
          'success!'
        else
          'failure!'
        end
      end

      expect(message).to receive(:data).and_return('{"username":"coyote"}')
      expect(subscription.main_callback(message)).to eql 'success!'
    end

    it 'dispatches the publisher_validation_token as part of the message' do
      subscription.register_callback(:dummy_command) do |message|
        if message.publisher_validation_token == 'dummy-token' && message.payload == {}
          'success!'
        else
          'failure!'
        end
      end

      expect(message).to receive(:attributes).and_return({ 'event' => 'dummy_command',
                                                           'publisher_validation_token' => 'dummy-token' })
      expect(subscription.main_callback(message)).to eql 'success!'
    end

    it 'dispatches the request_id as an attribute of the message and removes it from the payload, when present' do
      subscription.register_callback(:dummy_command) do |message|
        message.payload == {} && message.request_id == 'test-request-id' && 'success!'
      end

      expect(message).to receive(:data).and_return('{ "request_id": "test-request-id" }')
      expect(subscription.main_callback(message)).to eql 'success!'
    end

    context 'when message processing succeeds' do
      before { subscription.register_callback(:dummy_command) { puts 'Success!' } }

      it 'acknowledges the messgae' do
        expect(message).to receive(:ack!)

        subscription.main_callback(message)
      end
    end

    context "when there's no callback registered for the message" do
      it "acknowledges a message and logs an error if there's no callback registered for it" do
        expect(logger).to receive(:error)
        expect(message).to receive(:ack!)
        expect(subscription.main_callback(message)).to be_nil
      end
    end

    context 'when an error happens while processing the message' do
      before { subscription.register_callback(:dummy_command) { raise 'unexpected exception' } }

      it 'logs an error and rejects the message so it is available for redelivery' do
        expect(message).to receive(:reject!)
        expect(logger).to receive(:error)

        subscription.main_callback(message)
      end
    end
  end
end
