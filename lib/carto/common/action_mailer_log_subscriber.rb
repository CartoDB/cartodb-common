require 'action_mailer/log_subscriber'

##
# Extends ActionMailer::LogSubscriber to improve JSON logging capabilities
# Original source: https://github.com/rails/rails/blob/4-2-stable/actionmailer/lib/action_mailer/log_subscriber.rb
#
module Carto
  module Common
    class ActionMailerLogSubscriber < ActionMailer::LogSubscriber

      # Indicates Rails received a request to send an email.
      # The original payload of this event contains very little information
      def process(event)
        payload = event.payload

        info(
          message: 'Mail processed',
          mailer_class: payload[:mailer],
          mailer_action: payload[:action],
          duration_ms: event.duration.round(1)
        )
      end

      # Indicates Rails tried to send the email. Does not imply user received it,
      # as an error can still happen while sending it.
      def deliver(event)
        payload = event.payload

        info(
          message: 'Mail sent',
          mailer_class: payload[:mailer],
          message_id: payload[:message_id],
          current_user: current_user(payload),
          email_subject: payload[:subject],
          email_to_hint: email_to_hint(payload),
          email_from: payload[:from],
          email_date: payload[:date]
        )
      end

      private

      def current_user(event_payload)
        user_klass = defined?(Carto::User) ? Carto::User : User
        user_klass.find_by(email: event_payload[:to])&.username
      end

      def email_to_hint(event_payload)
        email_to = event_payload[:to]

        if email_to.is_a?(Array)
          email_to.map { |address| email_address_hint(address) }
        else
          [email_address_hint(email_to)]
        end
      end

      def email_address_hint(address)
        return unless address.present?
        if address.exclude?('@') ||
           address.length < 8 ||
           address.split('@').select(&:present?).size != 2
          return '[ADDRESS]'
        end

        address.split('@').map { |segment| "#{segment[0]}*****#{segment[-1]}" }.join('@')
      end

    end
  end
end
