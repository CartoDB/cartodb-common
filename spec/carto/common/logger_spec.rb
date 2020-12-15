require 'spec_helper'
require 'carto/common/current_request'
require './spec/support/log_device_mock'

RSpec.describe Carto::Common::Logger do
  subject(:logger) { described_class.new }

  let(:exception) { StandardError.new('Exception message') }
  let(:message) { 'Message' }

  describe 'common' do
    it 'propagates the request_id' do
      Carto::Common::CurrentRequest.request_id = SecureRandom.hex

      output = LogDeviceMock.capture_output(logger) do
        logger.info(message: message)
      end

      Carto::Common::CurrentRequest.request_id = nil

      expect(output).to match(/"request_id":"(\d|[a-z]){32}"/)
    end

    it 'does not override the request_id if already present' do
      output = LogDeviceMock.capture_output(logger) do
        logger.info(message: message, request_id: 'original-request-id')
      end

      expect(output).to match(/"request_id":"original-request-id"/)
    end
  end

  describe '#error' do
    it 'logs complex messages to Rollbar' do
      expect(Rollbar).to receive(:error).with(exception, message)

      logger.error(message: message, exception: exception)
    end

    it 'logs simple messages to Rollbar' do
      expect(Rollbar).to receive(:error).with(message)

      logger.error(message)
    end

    it 'allows skipping logging to Rollbar' do
      expect(Rollbar).not_to receive(:error)

      logger.error(message: message, rollbar: false)
    end
  end

  describe '#fatal' do
    it 'logs complex messages to Rollbar' do
      expect(Rollbar).to receive(:error).with(exception, message)

      logger.fatal(message: message, exception: exception)
    end

    it 'logs simple messages to Rollbar' do
      expect(Rollbar).to receive(:error).with(message)

      logger.fatal(message)
    end

    it 'allows skipping logging to Rollbar' do
      expect(Rollbar).not_to receive(:error)

      logger.fatal(message: message, rollbar: false)
    end
  end
end
