module Carto
  module Common
    module JobLogger

      extend ActiveSupport::Concern

      class_methods do
        def after_enqueue(*args)
          log(message: 'Job enqueued', args: args)
        end

        def after_perform(*args)
          log(message: 'Job performed', args: args)
        end

        def on_failure(*args)
          log(message: 'Job failed', args: args)
        end

        def log(params)
          Rails.logger.info(
            component: 'central.resque',
            job_class: name,
            args: log_args(params[:args]),
            message: params[:message]
          )
        end

        def log_args(args)
          args.map do |arg|
            return arg.inspect unless arg.is_a?(Exception)

            parsed_args = { exception: { class: arg.class, message: arg.message } }
            parsed_args[:backtrace] = arg.backtrace unless Rails.env.production?

            parsed_args
          end
        end
      end

    end
  end
end