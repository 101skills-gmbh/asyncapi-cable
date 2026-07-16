require "spec_helper"

RSpec.describe AsyncapiCable::Runtime::ContractRegistry do
  let(:fixture_dir) { File.expand_path("../fixtures/asyncapi", __dir__) }

  def configure_with(dir)
    AsyncapiCable.reset_configuration!
    AsyncapiCable.configure do |c|
      c.schemas = {cable_internal: {component_scope: :cable_internal}}
      c.schema_output_dir = dir
      c.schema_output_format = :yaml
    end
    described_class.reset!
  end

  before { configure_with(fixture_dir) }
  after do
    described_class.reset!
    AsyncapiCable.reset_configuration!
  end

  describe "#broadcast_schemas_for" do
    it "matches a concrete stream to all of its channel's payload schema names" do
      matches = described_class.broadcast_schemas_for("42-user-job-status")

      expect(matches.size).to eq(1)
      expect(matches.first.schema_names).to contain_exactly(
        "CurrentUserJobStatusMessage", "CurrentUserActionJobStatusMessage"
      )
    end

    it "exposes the doc's components for the matched channel" do
      match = described_class.broadcast_schemas_for("42-user-job-status").first

      expect(match.components["schemas"]).to include(
        "CurrentUserJobStatusMessage", "JobStatusActionEnum"
      )
    end

    it "returns no matches for a stream with no channel in the contract" do
      expect(described_class.broadcast_schemas_for("some-undocumented-stream")).to be_empty
    end
  end

  describe "missing / empty contract (D3)" do
    it "loads zero channels and warns when the contract dir has no files" do
      logger = instance_double(Logger, warn: nil, info: nil)
      allow(AsyncapiCable::Runtime).to receive(:logger).and_return(logger)

      configure_with(File.expand_path("../fixtures/does-not-exist", __dir__))

      expect(described_class.broadcast_schemas_for("42-user-job-status")).to be_empty
      expect(logger).to have_received(:warn).with(/loaded 0 channels/)
    end
  end

  describe "memoization" do
    it "parses the contract once and reuses it" do
      expect(described_class.instance).to be(described_class.instance)
      described_class.broadcast_schemas_for("42-user-job-status")
      described_class.broadcast_schemas_for("42-user-job-status")
    end
  end
end
