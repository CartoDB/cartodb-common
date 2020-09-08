require 'spec_helper'

RSpec.describe Carto::Common::LoggerFormatter do
  subject { Carto::Common::LoggerFormatter.new }

  let(:severity) { 'INFO' }
  let(:time) { Time.now }
  let(:progname) {}

  context 'message format' do
    it 'accepts blank message' do
      output = subject.call(severity, time, progname, '')
      parsed_output = JSON.parse(output)

      expect(parsed_output).to be_present
    end

    it 'accepts nil messages' do
      output = subject.call(severity, time, progname, nil)
      parsed_output = JSON.parse(output)

      expect(parsed_output).to be_present
    end

    it 'renames message to event_message when message is a string' do
      output = subject.call(severity, time, progname, 'Something!')
      parsed_output = JSON.parse(output)

      expect(parsed_output['message']).to be_nil
      expect(parsed_output['event_message']).to eq('Something!')
    end

    it 'renames message to event_message when message is a hash' do
      output = subject.call(severity, time, progname, { message: 'Something!' })
      parsed_output = JSON.parse(output)

      expect(parsed_output['message']).to be_nil
      expect(parsed_output['event_message']).to eq('Something!')
    end

    it 'can deal with non-utf8 strings' do
      payload = {
        message: 'Something',
        body: "some non-utf8 \xe2 char",
        some_nested_field: {
          another_non_utf8: "another non-utf8 \xe2 char"
        },
        some_other_value: 42
      }
      output = subject.call(severity, time, progname, payload)
      parsed_output = JSON.parse(output)

      expect(parsed_output['event_message']).to eq('Something')
      expect(parsed_output['body']).to eq('some non-utf8 � char')
      expect(parsed_output['some_nested_field']['another_non_utf8']).to eq('another non-utf8 � char')
      expect(parsed_output['some_other_value']).to eq(42)
    end
  end

  context 'severity format' do
    it 'renames severity to levelname' do
      output = subject.call(severity, time, progname, 'Something!')
      parsed_output = JSON.parse(output)

      expect(parsed_output['severity']).to be_nil
      expect(parsed_output['levelname']).to eq('info')
    end

    it 'uses info as default severity' do
      output = subject.call(nil, time, progname, 'Something!')
      parsed_output = JSON.parse(output)

      expect(parsed_output['levelname']).to eq('info')
    end

    it 'renames WARN severity to warning' do
      output = subject.call('WARN', time, progname, 'Something!')
      parsed_output = JSON.parse(output)

      expect(parsed_output['levelname']).to eq('warning')
    end
  end

  it 'renames current_user to cdb-user' do
    output = subject.call(severity, time, progname, { message: 'Something!', current_user: 'peter' })
    parsed_output = JSON.parse(output)

    expect(parsed_output['current_user']).to be_nil
    expect(parsed_output['cdb-user']).to eq('peter')
  end

  it 'prints all the JSON info in a single line' do
    time = '2020-07-23T13:25:23.649+00:00'
    output = subject.call(severity, time, progname, 'Something!')

    expect(output).to eq("{\"event_message\":\"Something!\",\"timestamp\":\"#{time}\",\"levelname\":\"info\",\"cdb-user\":null}\n")
  end
end
