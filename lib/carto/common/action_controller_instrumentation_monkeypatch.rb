##
# Mokeypatch ActionController::Instrumentation to customize event payload for
# CARTO custom log subscribers
#
ActionController::Instrumentation.module_eval do

  def process_action(*args)
    raw_payload = {
      :controller => self.class.name,
      :action     => self.action_name,
      :params     => request.filtered_parameters,
      :format     => request.format.try(:ref),
      :method     => request.request_method,
      :path       => (request.fullpath rescue "unknown")
    }.merge(extra_log_context)

    ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

    ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
      begin
        result = super
        payload[:status] = response.status
        result
      ensure
        append_info_to_payload(payload)
      end
    end
  end

  def redirect_to(*args)
    ActiveSupport::Notifications.instrument("redirect_to.action_controller") do |payload|
      result = super
      payload[:status]   = response.status
      payload[:location] = response.filtered_location
      payload.merge!(extra_log_context)
      result
    end
  end

  def send_file(path, options={})
    ActiveSupport::Notifications.instrument("send_file.action_controller",
      options.merge(path: path).merge(extra_log_context)) do
      super
    end
  end

  def send_data(data, options = {})
    ActiveSupport::Notifications.instrument("send_data.action_controller", options.merge(extra_log_context)) do
      super
    end
  end

  private

  def halted_callback_hook(filter)
    ActiveSupport::Notifications.instrument("halted_callback.action_controller", extra_log_context.merge(filter: filter))
  end

  def extra_log_context
    username = self.respond_to?(:current_user) ? current_user&.username : nil
    context = { request_id: request.uuid }

    username ? context.merge(current_user: username) context
  end

end