##
# Extends Rails::Rack::Logger to support CARTO JSON logging schema
# Original source: https://github.com/rails/rails/blob/master/railties/lib/rails/rack/logger.rb
#
module Carto
  module Common
    class RackLoggerMiddleware < ::Rails::Rack::Logger

      # Complete with parameters that can be safely logged, as it is
      # safer to don't log anything by default.
      LOGGABLE_PARAMS = %w[
        id
        username
        created_at
        updated_at
      ].freeze

      private

      def started_request_message(request)
        obfuscated_query = deep_obfuscate_values(request.params.to_h.deep_symbolize_keys)
        {
          message: 'Received request',
          request_id: request.uuid,
          component: 'central.rails_server',
          request_method: request.request_method,
          request_url: request.url,
          request_path: request.path,
          remote_ip: request.remote_ip,
          timestamp: Time.now.to_default_s,
          query_string: Rack::Utils.build_nested_query(obfuscated_query)
        }
      end

      def deep_obfuscate_values(hash)
        hash.each do |key, value|
          if value.is_a?(Hash)
            deep_obfuscate_values(value)
          elsif value.is_a?(String)
            hash[key] = LOGGABLE_PARAMS.include?(key.to_s) ? value : obfuscate_string(value)
          elsif value.is_a?(Array)
            hash[key] = value.map { |entry| obfuscate_string(entry) }.join(",")
          else # ex. ActionDispatch::Http::UploadedFile
            hash[key] = "[Instance of #{value.class}]"
          end
        end
      end

      def obfuscate_string(value)
        ('*' * value.length)
      end
    end
  end
end
