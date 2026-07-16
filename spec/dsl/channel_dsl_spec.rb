require "spec_helper"
require "openapi_ruby"
require "asyncapi_cable/adapters/rspec"

AsyncapiCable::Adapters::RSpec.install!

class FakeJobStatusChannel
end

class FakeJobStatusMessage
  include OpenapiRuby::Components::Base

  component_scopes :cable

  schema({
    type: :object,
    properties: {
      action: {type: :string},
      status: {type: :string}
    },
    required: %w[action status],
    additionalProperties: false
  })
end

RSpec.describe FakeJobStatusChannel, type: :asyncapi do
  asyncapi_schema :cable_api

  channel "{user_id}-user-job-status" do
    parameter :user_id, schema: {type: :integer}

    broadcast "Receive job status update" do
      operationId "receiveJobStatus"
      message FakeJobStatusMessage
    end
  end

  let(:registered) { AsyncapiCable::Dsl::MetadataStore.contexts_for(:cable_api) }

  it "registers exactly one channel context" do
    expect(registered.size).to eq(1)
  end

  it "captures the stream template" do
    expect(registered.first.stream_template).to eq("{user_id}-user-job-status")
  end

  it "captures the channel class from described_class" do
    expect(registered.first.channel_class).to eq(FakeJobStatusChannel)
  end

  it "captures the user_id parameter" do
    expect(registered.first.parameters).to eq([
      {name: "user_id", schema: {type: :integer}, client_supplied: true}
    ])
  end

  it "captures the broadcast operation" do
    op = registered.first.operations.first
    expect(op.kind).to eq(:broadcast)
    expect(op.summary).to eq("Receive job status update")
    expect(op.operation_id).to eq("receiveJobStatus")
    expect(op.messages).to eq([FakeJobStatusMessage])
  end

  describe "#assert_asyncapi_broadcast" do
    before do
      AsyncapiCable.reset_configuration!
      AsyncapiCable::Runtime::PayloadValidator.reset!
    end

    it "passes and returns the decoded payloads when the triggered broadcast matches the schema" do
      payloads = assert_asyncapi_broadcast(params: {user_id: 42}) do
        ActionCable.server.broadcast("42-user-job-status", {action: "started", status: "ok"})
      end

      expect(payloads).to eq([{"action" => "started", "status" => "ok"}])
    end

    it "fails when the block does not broadcast on the expanded stream" do
      expect {
        assert_asyncapi_broadcast(params: {user_id: 42}) { nil }
      }.to raise_error(/Expected at least one broadcast on "42-user-job-status"/)
    end

    it "ignores broadcasts on other streams" do
      expect {
        assert_asyncapi_broadcast(params: {user_id: 42}) do
          ActionCable.server.broadcast("43-user-job-status", {action: "started", status: "ok"})
        end
      }.to raise_error(/Expected at least one broadcast/)
    end

    it "fails when a captured payload violates every declared message schema" do
      expect {
        assert_asyncapi_broadcast(params: {user_id: 42}) do
          ActionCable.server.broadcast("42-user-job-status", {action: "started"})
        end
      }.to raise_error(/AsyncAPI broadcast validation failed for "42-user-job-status"/)
    end

    it "raises when params do not resolve the stream template" do
      expect {
        assert_asyncapi_broadcast { nil }
      }.to raise_error(AsyncapiCable::Error, /Missing params \["user_id"\]/)
    end

    it "raises without a trigger block" do
      expect {
        assert_asyncapi_broadcast(params: {user_id: 42})
      }.to raise_error(AsyncapiCable::Error, /requires a block/)
    end
  end
end

RSpec.describe "a channel without broadcast operations", type: :asyncapi do
  asyncapi_schema :cable_api_subscribe_only

  channel "{user_id}-subscribe-only", channel_class: FakeJobStatusChannel do
    parameter :user_id, schema: {type: :integer}

    subscribe "Subscribe to job status"
  end

  it "raises from assert_asyncapi_broadcast" do
    expect {
      assert_asyncapi_broadcast(params: {user_id: 42}) { nil }
    }.to raise_error(AsyncapiCable::Error, /No channel with a broadcast operation/)
  end
end
