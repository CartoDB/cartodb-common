module Carto
  module Common
    class BaseCommand

      attr_accessor(
        :params,
        :logger,
        :request_id
      )

      def self.run(params = {})
        new(params).run
      end

      def initialize(params = {}, extra_context = {})
        self.params = params.with_indifferent_access
        self.logger = extra_context[:logger] || Rails.logger
        self.request_id = Carto::Common::CurrentRequest.request_id || extra_context[:request_id]
      end

      def run
        Carto::Common::CurrentRequest.with_request_id(request_id) do
          begin
            before_run_hooks
            run_command
          rescue StandardError => e
            logger.error(
              log_context.merge(
                message: 'Command failed',
                exception: e,
                rollbar: false # Don't report to Rollbar twice, as we're re-raising the exception afterwards
              )
            )
            raise e
          ensure
            after_run_hooks
          end
        end
      end

      private

      def run_command
        raise 'This method must be overriden'
      end

      def before_run_hooks
        logger.info(log_context.merge(message: 'Started command'))
      end

      def after_run_hooks
        logger.info(log_context.merge(message: 'Finished command'))
      end

      def log_context
        { command_class: self.class.name, request_id: request_id }
      end

    end
  end
end
