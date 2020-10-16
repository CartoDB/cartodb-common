require 'spec_helper'
require './lib/carto/common/action_mailer_log_subscriber'

RSpec.describe 'Carto::Common::ActionMailerLogSubscriber' do
  subject { Carto::Common::ActionMailerLogSubscriber.new }

  # Mocks CartoDB & Central users as they don't exist in the context of this gem
  class User

    attr_accessor :email, :username

    @users = []

    def self.users
      @users
    end

    def self.find_by(params = {})
      @users.select { |user| user.email == params[:email] }.first
    end

    def initialize(params = {})
      self.email = params[:email]
      self.username = params[:username]
      User.users << self
      self
    end

  end

  let(:event_name) {}
  let(:event_payload) { {} }
  let(:event) { ActiveSupport::Notifications::Event.new(event_name, Time.now, Time.now + 1.second, 1, event_payload) }

  context '#process' do
    let(:event_name) { 'process.action_mailer' }
    let(:event_payload) { { mailer: 'DummyMailer', action: 'dummy_mailer_method' } }

    it 'logs email processing' do
      expect(subject).to receive(:info).with(
        message: 'Mail processed',
        mailer_class: 'DummyMailer',
        mailer_action: 'dummy_mailer_method',
        duration_ms: 1000.0
      )

      subject.process(event)
    end
  end

  context '#deliver' do
    let(:user) { User.new(email: 'somebody@example.com') }
    let(:event_name) { 'deliver.action_mailer' }
    let(:receiver_addresses) { [user.email] }
    let(:event_payload) do
      {
        mailer: 'DummyMailer',
        message_id: 1,
        subject: 'Subject',
        from: ['foo@bar.com'],
        to: receiver_addresses
      }
    end

    it 'logs email delivery' do
      expect(subject).to receive(:info).with(
        message: 'Mail sent',
        mailer_class: 'DummyMailer',
        message_id: 1,
        current_user: user.username,
        email_subject: 'Subject',
        email_to_hint: ['s******y@e*********m'],
        email_from: ['foo@bar.com'],
        email_date: nil
      )

      subject.deliver(event)
    end

    context 'when several receivers' do
      let(:receiver_addresses) { ['first@mail.com', 'second@mail.com'] }

      it 'logs all the addresses' do
        expect(subject).to receive(:info).with(hash_including(email_to_hint: ['f***t@m******m', 's****d@m******m']))
        subject.deliver(event)
      end
    end

    context 'when receiver address is missing' do
      let(:receiver_addresses) { nil }

      it 'does not break' do
        expect(subject).to receive(:info).with(hash_including(email_to_hint: [nil]))
        subject.deliver(event)
      end
    end

    context 'when receiver address is incorrect' do
      let(:receiver_addresses) { ['@incorrect'] }

      it 'logs a special string' do
        expect(subject).to receive(:info).with(hash_including(email_to_hint: ['[ADDRESS]']))
        subject.deliver(event)
      end
    end

    context 'when receiver address is very short' do
      let(:receiver_addresses) { ['a@b.com'] }

      it 'logs a special string' do
        expect(subject).to receive(:info).with(hash_including(email_to_hint: ['[ADDRESS]']))
        subject.deliver(event)
      end
    end
  end
end
