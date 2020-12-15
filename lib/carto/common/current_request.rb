module Carto
  module Common
    module CurrentRequest

      def self.request_id
        Thread.current[:request_id]
      end

      def self.request_id=(request_id)
        Thread.current[:request_id] = request_id
      end

      def self.with_request_id(request_id)
        self.request_id = request_id if request_id
        yield
      ensure
        self.request_id = nil
      end

    end
  end
end
