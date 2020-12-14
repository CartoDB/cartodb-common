class LogDeviceMock < Logger::LogDevice

  attr_accessor :written_text

  def write(text)
    super(text)
    self.written_text = '' unless written_text
    self.written_text += text
  end

  def self.capture_output(logger)
    original_log_device = logger.instance_variable_get(:@logdev)
    mock_log_device = new('tmp/log_device_mock.log')
    logger.instance_variable_set(:@logdev, mock_log_device)
    yield
    logger.instance_variable_set(:@logdev, original_log_device)
    mock_log_device.written_text
  end

end
