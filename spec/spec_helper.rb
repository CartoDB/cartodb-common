require "bundler/setup"
require "carto/common/encryption_service"
require 'carto/common/logger'
require "carto/common/logger_formatter"
require 'google/cloud/pubsub'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# See https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/dynamic-classes
# rubocop:disable Lint/UselessMethodDefinition
class PubsubDouble

  include Google::Cloud::Pubsub

  def create_topic(*)
    super
  end

  def get_topic(*)
    super
  end

  def get_subscription(*)
    super
  end

end

class PubsubMessageDouble < Google::Cloud::Pubsub::Message

  def ack!(*)
    super
  end

  def reject!(*)
    super
  end

end
# rubocop:enable Lint/UselessMethodDefinition
