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
  end

  describe '#fatal' do
    it 'logs complex messages to Rollbar' do
      expect(Rollbar).to receive(:error).with(exception, message)

      logger.fatal(message: message, exception: exception)
    end

    it 'logs simple messages to Rollbar' do
      expect(Rollbar).to receive(:error).with(message)

      logger.error(message)
    end
  end
end
