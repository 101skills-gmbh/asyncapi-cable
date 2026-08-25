require "spec_helper"
require "minitest"
require "openapi_ruby"
require "asyncapi_cable/adapters/minitest"

class MinitestSpecFakeChannel
end

class MinitestSpecFakeMessage
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

class MinitestSpecFakeTestClass < ::Minitest::Test
  include AsyncapiCable::Adapters::Minitest::DSL

  asyncapi_schema :minitest_adapter_test

  channel "{user_id}-minitest-fake", channel_class: MinitestSpecFakeChannel do
    parameter :user_id, schema: {type: :integer}

    broadcast "Receive fake update" do
      operationId "receiveMinitestFake"
      message MinitestSpecFakeMessage
    end
  end

  def passing_test
  end
end

RSpec.describe AsyncapiCable::Adapters::Minitest do
  let(:registered) do
    AsyncapiCable::Dsl::MetadataStore.contexts_for(:minitest_adapter_test)
  end

  it "registers exactly one channel context from the class-level DSL" do
    expect(registered.size).to eq(1)
  end

  it "captures the stream template" do
    expect(registered.first.stream_template).to eq("{user_id}-minitest-fake")
  end

  it "captures channel_class from the keyword argument" do
    expect(registered.first.channel_class).to eq(MinitestSpecFakeChannel)
  end

  it "captures parameters declared inside the channel block" do
    expect(registered.first.parameters).to eq([
      {name: "user_id", schema: {type: :integer}, client_supplied: true}
    ])
  end

  it "captures broadcast operations with operationId and message" do
    op = registered.first.operations.first
    expect(op.kind).to eq(:broadcast)
    expect(op.summary).to eq("Receive fake update")
    expect(op.operation_id).to eq("receiveMinitestFake")
    expect(op.messages).to eq([MinitestSpecFakeMessage])
  end

  it "keeps the declared contexts on the test class" do
    expect(MinitestSpecFakeTestClass._asyncapi_contexts.map(&:stream_template))
      .to eq(["{user_id}-minitest-fake"])
  end

  describe "#assert_asyncapi_broadcast" do
    let(:test_instance) { MinitestSpecFakeTestClass.new(:passing_test) }

    before do
      AsyncapiCable.reset_configuration!
      AsyncapiCable::Runtime::PayloadValidator.reset!
    end

    it "passes and returns the decoded payloads when the triggered broadcast matches the schema" do
      payloads = test_instance.assert_asyncapi_broadcast(params: {user_id: 42}) do
        ActionCable.server.broadcast("42-minitest-fake", {action: "started", status: "ok"})
      end

      expect(payloads).to eq([{"action" => "started", "status" => "ok"}])
    end

    it "fails with a Minitest::Assertion when the block does not broadcast" do
      expect {
        test_instance.assert_asyncapi_broadcast(params: {user_id: 42}) { nil }
      }.to raise_error(::Minitest::Assertion, /Expected at least one broadcast/)
    end

    it "fails with a Minitest::Assertion when a payload violates the schema" do
      expect {
        test_instance.assert_asyncapi_broadcast(params: {user_id: 42}) do
          ActionCable.server.broadcast("42-minitest-fake", {action: "started"})
        end
      }.to raise_error(::Minitest::Assertion, /broadcast validation failed/)
    end

    # The capture already decodes one layer, so a site that broadcasts
    # pre-serialized JSON still leaves a String where the schema wants an
    # object. Say which of the two it is.
    it "names the cause when the broadcast site passed serialized JSON" do
      expect {
        test_instance.assert_asyncapi_broadcast(params: {user_id: 42}) do
          ActionCable.server.broadcast("42-minitest-fake", {action: "started", status: "ok"}.to_json)
        end
      }.to raise_error(::Minitest::Assertion, /JSON string rather than an object/)
    end

    it "raises when params do not resolve the stream template" do
      expect {
        test_instance.assert_asyncapi_broadcast { nil }
      }.to raise_error(AsyncapiCable::Error, /Missing params \["user_id"\]/)
    end
  end
end
