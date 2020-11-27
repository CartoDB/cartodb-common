require 'rollbar'

require_relative 'action_controller_log_subscriber'
require_relative 'action_mailer_log_subscriber'
require_relative 'logger_formatter'
require_relative 'rack_logger_middleware'

module Carto
  module Common
    class Logger < ActiveSupport::Logger

      ##
      # Removes Rails default log subscribers and replaces with the CARTO custom ones
      # Replaces default Rack logging middleware with CARTO custom one
      #
      def self.install
        require_relative('action_controller_instrumentation_monkeypatch')
        remove_existing_log_subscriptions
        attach_custom_log_subscribers
        swap_rack_logging_middleware
      end

      def self.remove_existing_log_subscriptions
        ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
          case subscriber
          when ActionView::LogSubscriber
            unsubscribe(:action_view, subscriber)
          when ActionController::LogSubscriber
            unsubscribe(:action_controller, subscriber)
          when ActionMailer::LogSubscriber
            unsubscribe(:action_mailer, subscriber)
          end
        end
      end
      private_class_method :remove_existing_log_subscriptions

      def self.attach_custom_log_subscribers
        Carto::Common::ActionControllerLogSubscriber.attach_to(:action_controller)
        Carto::Common::ActionMailerLogSubscriber.attach_to(:action_mailer)
      end
      private_class_method :attach_custom_log_subscribers

      def self.swap_rack_logging_middleware
        Rails.configuration.middleware.swap(Rails::Rack::Logger, Carto::Common::RackLoggerMiddleware)
      end
      private_class_method :swap_rack_logging_middleware

      def self.unsubscribe(component, subscriber)
        events = subscriber.public_methods(false).reject { |method| method.to_s == 'call' }
        events.each do |event|
          ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
            if listener.instance_variable_get('@delegate') == subscriber
              ActiveSupport::Notifications.unsubscribe listener
            end
          end
        end
      end
      private_class_method :unsubscribe

      def initialize(output_stream = $stdout)
        super(output_stream)
        self.formatter = Carto::Common::LoggerFormatter.new
      end

      def error(params = {})
        super(params)
        send_exception_to_rollbar(params)
      end

      def fatal(params = {})
        super(params)
        send_exception_to_rollbar(params)
      end

      private

      def send_exception_to_rollbar(params = {})
        if params.is_a?(Hash)
          exception = params[:exception]
          message = params[:message]

          if message && exception && exception.is_a?(Exception)
            Rollbar.error(exception, message)
          else
            Rollbar.error(exception || message)
          end
        else
          Rollbar.error(params)
        end
      end

    end
  end
end
