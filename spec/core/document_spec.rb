require "spec_helper"
require "openapi_ruby"
require "asyncapi_cable/adapters/rspec"

AsyncapiCable::Adapters::RSpec.install!

class DocFakeChannel
end

class DocFakeMessage
  include OpenapiRuby::Components::Base

  component_scopes :cable

  schema({
    type: :object,
    properties: {action: {type: :string}, status: {type: :string}},
    required: %w[action status]
  })
end

RSpec.describe AsyncapiCable::Core::Document do
  let(:channel_context) do
    ctx = AsyncapiCable::Dsl::ChannelContext.new(
      "{user_id}-doc-fake",
      channel_class: DocFakeChannel,
      schema_name: :cable_api
    )
    ctx.parameter(:user_id, schema: {type: :integer}, client_supplied: false)
    ctx.parameter(:kind, description: "Kind", schema: {type: :string, enum: %w[a b], default: "a"})
    ctx.broadcast("Receive doc fake update") do
      operationId "receiveDocFake"
      message DocFakeMessage
    end
    ctx
  end

  let(:cable_components) do
    {"schemas" => {"DocFakeMessage" => DocFakeMessage._schema_definition}}
  end

  subject(:document) do
    doc = described_class.new(
      info: {title: "Cable API", version: "0.1.0"},
      servers: {dev: {host: "localhost:3000", pathname: "/cable", protocol: "ws"}},
      cable_components: cable_components
    )
    doc.add_channel(channel_context)
    doc
  end

  let(:hash) { document.to_h }

  it "declares AsyncAPI 3.0.0" do
    expect(hash["asyncapi"]).to eq("3.0.0")
  end

  it "carries the info block" do
    expect(hash["info"]).to eq("title" => "Cable API", "version" => "0.1.0")
  end

  it "serializes servers as a map (AsyncAPI 3.0.0 shape)" do
    expect(hash["servers"]).to eq(
      "dev" => {"host" => "localhost:3000", "pathname" => "/cable", "protocol" => "ws"}
    )
  end

  it "registers the channel under its demodulized class name minus 'Channel'" do
    expect(hash["channels"].keys).to eq(["DocFake"])
    expect(hash["channels"]["DocFake"]["address"]).to eq("{user_id}-doc-fake")
  end

  it "carries the Rails channel class name as x-actioncable-channel" do
    expect(hash["channels"]["DocFake"]["x-actioncable-channel"]).to eq("DocFakeChannel")
  end

  it "emits AsyncAPI 3.0 parameters: no `schema`; marks server-derived params" do
    expect(hash["channels"]["DocFake"]["parameters"]).to eq(
      "user_id" => {"x-client-supplied" => false},
      "kind" => {"description" => "Kind", "enum" => %w[a b], "default" => "a"}
    )
  end

  it "references messages from the channel by component name" do
    expect(hash["channels"]["DocFake"]["messages"]).to eq(
      "DocFakeMessage" => {"$ref" => "#/components/messages/DocFakeMessage"}
    )
  end

  it "emits broadcast operations with action: receive" do
    op = hash["operations"]["receiveDocFake"]
    expect(op["action"]).to eq("receive")
    expect(op["channel"]).to eq("$ref" => "#/channels/DocFake")
    expect(op["messages"]).to eq([{"$ref" => "#/channels/DocFake/messages/DocFakeMessage"}])
    expect(op["summary"]).to eq("Receive doc fake update")
  end

  it "registers AsyncAPI Message components wrapping the schema" do
    expect(hash["components"]["messages"]).to eq(
      "DocFakeMessage" => {"payload" => {"$ref" => "#/components/schemas/DocFakeMessage"}}
    )
  end

  it "carries cable-scoped schemas through to components.schemas" do
    expect(hash["components"]["schemas"]).to have_key("DocFakeMessage")
  end

  it "round-trips through YAML without losing keys" do
    require "yaml"
    parsed = YAML.safe_load(document.to_yaml, permitted_classes: [Symbol])
    expect(parsed["asyncapi"]).to eq("3.0.0")
    expect(parsed.dig("channels", "DocFake", "address")).to eq("{user_id}-doc-fake")
  end
end
