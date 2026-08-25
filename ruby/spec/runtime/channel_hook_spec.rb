require "spec_helper"

class FakeBroadcastingServer
  prepend AsyncapiCable::Runtime::ChannelHook

  attr_reader :received

  def initialize
    @received = []
  end

  def broadcast(stream, payload)
    @received << [stream, payload]
  end
end

RSpec.describe AsyncapiCable::Runtime::ChannelHook do
  let(:fixture_dir) { File.expand_path("../fixtures/asyncapi", __dir__) }
  let(:server) { FakeBroadcastingServer.new }
  let(:stream) { "7-user-job-status" }
  let(:valid_payload) { {action: "image_generation", user_id: "u-7", status: "completed"} }
  let(:action_job_payload) { {status: "completed", name: "Tools::Api::RemixActionJob"} }
  let(:invalid_payload) { {action: "image_generation", user_id: "u-7"} }

  before do
    AsyncapiCable.reset_configuration!
    AsyncapiCable.configure do |c|
      c.schemas = {cable_internal: {component_scope: :cable_internal}}
      c.schema_output_dir = fixture_dir
      c.schema_output_format = :yaml
    end
    AsyncapiCable::Runtime::PayloadValidator.reset!
    AsyncapiCable::Runtime::ContractRegistry.reset!
  end

  after do
    AsyncapiCable::Runtime::ContractRegistry.reset!
    AsyncapiCable::Runtime::PayloadValidator.reset!
    AsyncapiCable.reset_configuration!
  end

  describe "default mode (:disabled)" do
    it "passes invalid payloads through untouched" do
      server.broadcast(stream, invalid_payload)
      expect(server.received).to eq([[stream, invalid_payload]])
    end
  end

  describe ":warn_only mode" do
    before { AsyncapiCable.configure { |c| c.validation_mode = :warn_only } }

    it "logs a warning and still delivers the broadcast" do
      logger = instance_double(Logger, warn: nil, info: nil)
      allow(AsyncapiCable::Runtime).to receive(:logger).and_return(logger)

      server.broadcast(stream, invalid_payload)

      expect(logger).to have_received(:warn).with(/AsyncAPI broadcast validation failed.*user-job-status/)
      expect(server.received.size).to eq(1)
    end

    it "stays silent for valid payloads" do
      logger = instance_double(Logger, warn: nil, info: nil)
      allow(AsyncapiCable::Runtime).to receive(:logger).and_return(logger)

      server.broadcast(stream, valid_payload)

      expect(logger).not_to have_received(:warn)
      expect(server.received.size).to eq(1)
    end

    # "value at root is not an object" sends you looking at the schema when the
    # cause is the broadcast site handing over a serialized String.
    it "names the cause when the payload was serialized a layer too early" do
      logger = instance_double(Logger, warn: nil, info: nil)
      allow(AsyncapiCable::Runtime).to receive(:logger).and_return(logger)

      server.broadcast(stream, valid_payload.to_json)

      expect(logger).to have_received(:warn).with(/JSON string rather than an object/)
    end
  end

  describe ":enabled mode" do
    before { AsyncapiCable.configure { |c| c.validation_mode = :enabled } }

    it "raises on invalid payloads and does not deliver" do
      expect { server.broadcast(stream, invalid_payload) }
        .to raise_error(AsyncapiCable::Error, /validation failed/)
      expect(server.received).to be_empty
    end

    it "lets valid payloads through" do
      expect { server.broadcast(stream, valid_payload) }.not_to raise_error
      expect(server.received.size).to eq(1)
    end

    it "accepts a payload matching the alternative (name-based) message" do
      expect { server.broadcast(stream, action_job_payload) }.not_to raise_error
      expect(server.received.size).to eq(1)
    end
  end

  describe "undocumented streams" do
    before { AsyncapiCable.configure { |c| c.validation_mode = :enabled } }

    it "skips validation when no channel address matches the stream" do
      expect { server.broadcast("unknown-stream-xyz", invalid_payload) }.not_to raise_error
      expect(server.received.size).to eq(1)
    end
  end

  describe AsyncapiCable::Runtime::StreamMatcher do
    it "matches a templated stream with a parameter" do
      expect(described_class.new("{user_id}-user-job-status").match?("47-user-job-status")).to be(true)
    end

    it "does not match a different template" do
      expect(described_class.new("{user_id}-user-job-status").match?("47-other-stream")).to be(false)
    end

    it "matches a literal stream with no parameters" do
      expect(described_class.new("global-events").match?("global-events")).to be(true)
    end
  end
end
