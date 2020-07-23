##
# Extends Rails::Rack::Logger to support CARTO JSON logging schema
# Original source: https://github.com/rails/rails/blob/master/railties/lib/rails/rack/logger.rb
#
module Carto
  module Common
    class RackLoggerMiddleware < ::Rails::Rack::Logger

      private

      def started_request_message(request)
        {
          message: 'Received request',
          request_id: request.uuid,
          component: 'central.rails_server',
          request_method: request.request_method,
          request_url: request.url,
          request_path: request.path,
          remote_ip: request.remote_ip,
          timestamp: Time.now.to_default_s,
          params: deep_obfuscate_values(request.params.to_h.deep_symbolize_keys),
        }
      end

      def deep_obfuscate_values(hash)
        hash.each do |key, value|
          if value.is_a?(Hash)
            deep_obfuscate_values(value)
          elsif key.match?(/password|auth|token|crypt|secret/i)
            hash[key] = '[FILTERED]'
          end
        end
      end

    end
  end
end