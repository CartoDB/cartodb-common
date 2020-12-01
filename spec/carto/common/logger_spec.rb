require 'spec_helper'

RSpec.describe Carto::Common::Logger do
  subject(:logger) { described_class.new }

  let(:exception) { StandardError.new('Exception message') }
  let(:message) { 'Message' }

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
