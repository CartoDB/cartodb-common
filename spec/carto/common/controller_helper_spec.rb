require 'spec_helper'
require './lib/carto/common/controller_helper'

class ControllerMock

  class Request

    attr_accessor :uuid

    def initialize
      self.uuid = SecureRandom.hex
    end

  end

  include Carto::Common::ControllerHelper

  def index
    set_request_id do
      logger.info(request_id: Carto::Common::CurrentRequest.request_id)
    end
  end

  def logger
    @logger ||= Carto::Common::Logger.new
  end

  private

  def request
    @request ||= Request.new
  end

end

RSpec.describe Carto::Common::ControllerHelper do
  describe '#set_request_id' do
    let(:controller) { ControllerMock.new }

    it 'sets the request ID for each request' do
      expect(controller.logger).to receive(:info).with(hash_including(request_id: kind_of(String)))

      controller.index
    end

    it 'clears the thread-level variable after the request finishes' do
      controller.index

      expect(Carto::Common::CurrentRequest.request_id).to be_nil
    end
  end
end
