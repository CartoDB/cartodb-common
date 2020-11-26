require 'active_support'
require 'active_support/core_ext'
require 'json'

module Carto
  module Common
    class LoggerFormatter < ::ActiveSupport::Logger::Formatter
      def call(severity, time, _progname, message)
        original_message = message.is_a?(Hash) ? message : { event_message: message }

        message_hash = deep_safe_utf8_encode(
          ActiveSupport::HashWithIndifferentAccess.new(
            original_message.merge(
              timestamp: time,
              levelname: levelname(severity)
            )
          )
        )

        # Serialize Exception objects
        exception = message_hash[:exception]
        if exception.is_a?(Exception)
          message_hash[:exception] = {
            class: exception.class.name,
            message: exception.message,
            backtrace_hint: production_environment? ? exception.backtrace&.take(10) : exception.backtrace
          }
          message_hash[:message] = exception.message if message_hash[:message].blank?
        end

        replace_key(message_hash, :current_user, :'cdb-user')
        replace_key(message_hash, :message, :event_message)

        development_environment? ? "#{JSON.pretty_generate(message_hash)}\n" : "#{message_hash.to_json}\n"
      end

      private

      def levelname(severity)
        return 'info' if severity.blank?

        level = severity.to_s.downcase
        level == "warn" ? "warning" : level
      end

      def development_environment?
        ENV['RAILS_ENV'].to_s.casecmp('development').zero?
      end

      def production_environment?
        ENV['RAILS_ENV'].to_s.casecmp('production').zero?
      end

      def replace_key(message_hash, old_key, new_key)
        value = message_hash.delete(old_key)
        message_hash[new_key] = value if message_hash[new_key].nil?
      end

      def deep_safe_utf8_encode(hash)
        hash.transform_values do |value|
          if value.is_a?(String)
            value.encode('UTF-8', 'UTF-8', invalid: :replace)
          elsif value.is_a?(Hash)
            deep_safe_utf8_encode(value)
          else
            value
          end
        end
      end
    end
  end
end
