require "spec_helper"

RSpec.describe AsyncapiCable do
  before { described_class.reset_configuration! }

  it "has a version number" do
    expect(AsyncapiCable::VERSION).to be_a(String)
  end

  it "defines an isolated Rails engine" do
    expect(AsyncapiCable::Engine.ancestors).to include(Rails::Engine)
  end

  describe ".configure" do
    it "yields the configuration" do
      described_class.configure do |config|
        config.schemas = {cable_api: {info: {title: "Cable API"}}}
      end

      expect(described_class.configuration.schemas).to eq(cable_api: {info: {title: "Cable API"}})
    end

    it "defaults validation_mode to :disabled" do
      expect(described_class.configuration.validation_mode).to eq(:disabled)
    end

    it "rejects unknown validation modes" do
      expect {
        described_class.configure { |c| c.validation_mode = :loud }
      }.to raise_error(ArgumentError, /validation_mode must be one of/)
    end
  end
end
