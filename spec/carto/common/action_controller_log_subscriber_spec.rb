require 'spec_helper'
require './lib/carto/common/action_controller_log_subscriber'

RSpec.describe Carto::Common::ActionControllerLogSubscriber do
  subject(:log_subscriber) { described_class.new }

  let(:event_name) {}
  let(:event_payload) { {} }
  let(:event) do
    ActiveSupport::Notifications::Event.new(
      event_name,
      Time.current,
      Time.current + 1.second, 1,
      event_payload
    )
  end

  describe '#process_action' do
    let(:event_name) { 'start_processing.action_controller' }
    let(:base_payload) do
      {
        controller: 'UsersController',
        action: 'index',
        params: { 'action' => 'index', 'controller' => 'users' },
        headers: ActionDispatch::Http::Headers.new({}),
        format: :html,
        method: 'GET',
        path: '/users'
      }
    end

    context 'when exception is present' do
      let(:event_payload) { base_payload.merge(status: 500, exception: [StandardError.new('Exception message')]) }

      it 'logs request completion' do
        expect(log_subscriber).to receive(:error).with(
          message: 'Request completed',
          request_id: nil,
          current_user: nil,
          duration_ms: 1000,
          view_duration_ms: nil,
          db_duration_ms: nil,
          status: 500,
          status_text: 'Internal Server Error',
          rollbar: false,
          exception: { message: 'Exception message' }
        )

        log_subscriber.process_action(event)
      end
    end

    context 'when returning an error code without exception' do
      let(:event_payload) { base_payload.merge(status: 500) }

      it 'logs request completion' do
        expect(log_subscriber).to receive(:error).with(
          message: 'Request completed',
          request_id: nil,
          current_user: nil,
          duration_ms: 1000,
          view_duration_ms: nil,
          db_duration_ms: nil,
          status: 500,
          status_text: 'Internal Server Error',
          rollbar: false
        )

        log_subscriber.process_action(event)
      end
    end

    context 'when everything is ok' do
      let(:event_payload) { base_payload.merge(status: 200) }

      it 'logs request completion' do
        expect(log_subscriber).to receive(:info).with(
          message: 'Request completed',
          request_id: nil,
          current_user: nil,
          duration_ms: 1000,
          view_duration_ms: nil,
          db_duration_ms: nil,
          status: 200,
          status_text: 'OK'
        )

        log_subscriber.process_action(event)
      end
    end
  end
end
