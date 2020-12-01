require 'action_controller'
require 'action_controller/log_subscriber'

##
# Extends ActionController::LogSubscriber to improve JSON logging capabilities
# Original source: https://github.com/rails/rails/blob/4-2-stable/actionpack/lib/action_controller/log_subscriber.rb
#
module Carto
  module Common
    class ActionControllerLogSubscriber < ActionController::LogSubscriber

      def start_processing(event)
        payload = event.payload

        info(
          message: "Processing request",
          request_id: payload[:request_id],
          current_user: payload[:current_user],
          controller: "#{payload[:controller]}##{payload[:action]}",
          controller_format: payload[:format].to_s.upcase,
        )
      end

      def process_action(event)
        payload = event.payload
        status = payload[:status]
        exception = payload[:exception]

        log_entry = {
          message: 'Request completed',
          request_id: payload[:request_id],
          current_user: payload[:current_user],
          duration_ms: event.duration.round,
          view_duration_ms: payload[:view_runtime],
          db_duration_ms: payload[:db_runtime]
        }

        if exception.present?
          status ||= ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.first)
          log_entry[:exception] = { message: exception.join(': ') }
        end
        log_entry.merge!(status: status, status_text: Rack::Utils::HTTP_STATUS_CODES[status])

        if exception.present? || status.to_s.match?(/5\d\d/)
          error(log_entry.merge(rollbar: false))
        else
          info(log_entry)
        end
      end

      def halted_callback(event)
        info(
          message: 'Filter chain halted (rendered or redirected)',
          request_id: event.payload[:request_id],
          current_user: event.payload[:current_user],
          filter: event.payload[:filter].inspect
        )
      end

      def send_file(event)
        info(
          message: 'Sent file',
          request_id: event.payload[:request_id],
          current_user: event.payload[:current_user],
          file: event.payload[:path],
          duration_ms: event.duration.round(1)
        )
      end

      def redirect_to(event)
        info(
          message: "Redirected",
          request_id: event.payload[:request_id],
          current_user: event.payload[:current_user],
          location: event.payload[:location]
        )
      end

      def send_data(event)
        info(
          message: "Sent data",
          request_id: event.payload[:request_id],
          current_user: event.payload[:current_user],
          file: event.payload[:filename],
          duration_ms: event.duration.round(1)
        )
      end

      def unpermitted_parameters(event)
        debug(
          message: "Unpermitted parameter",
          request_id: event.payload[:request_id],
          current_user: event.payload[:current_user],
          unpermitted_params: event.payload[:keys]
        )
      end

    end
  end
end
