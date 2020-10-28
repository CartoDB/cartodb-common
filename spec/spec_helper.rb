require "bundler/setup"
require "carto/common/encryption_service"
require "carto/common/logger_formatter"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

module LoggerHelper
  def log_debug(params = {}); end
  def log_info(params = {}); end
  def log_warning(params = {}); end
  def log_error(params = {}); end
  def log_fatal(params = {}); end
end
