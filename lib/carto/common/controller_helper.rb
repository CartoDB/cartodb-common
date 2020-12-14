require 'carto/common/current_request'

module Carto
  module Common
    module ControllerHelper

      def set_request_id
        Carto::Common::CurrentRequest.request_id = request.uuid
        begin
          yield
        ensure
          Carto::Common::CurrentRequest.request_id = nil
        end
      end

    end
  end
end
