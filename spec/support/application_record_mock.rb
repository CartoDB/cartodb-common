class ApplicationRecordMock < OpenStruct

  @records = []

  class << self

    attr_accessor :records

  end

  def self.create(params = {})
    new(params)
  end

  def self.find_by(params = {})
    ApplicationRecordMock.records.find do |record|
      params.all? { |key, value| record[key] == value }
    end
  end

  def initialize(params = {})
    super(params)
    ApplicationRecordMock.records << self
  end

end
