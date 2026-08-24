require "spec_helper"
require "tmpdir"
require "yaml"
require "openapi_ruby"
require "asyncapi_cable/adapters/rspec"

AsyncapiCable::Adapters::RSpec.install!

class WriterFakeChannel
end

class WriterFakeMessage
  include OpenapiRuby::Components::Base

  component_scopes :cable

  schema({
    type: :object,
    properties: {action: {type: :string}},
    required: %w[action]
  })
end

RSpec.describe AsyncapiCable::Generator::AsyncapiWriter do
  before do
    AsyncapiCable.reset_configuration!
    AsyncapiCable::Dsl::MetadataStore.clear!(scope: :writer_test)

    AsyncapiCable.configure do |config|
      config.schemas = {
        writer_test: {
          info: {title: "Cable API", version: "0.1.0"},
          servers: {dev: {host: "localhost:3000", pathname: "/cable", protocol: "ws"}}
        }
      }
    end

    ctx = AsyncapiCable::Dsl::ChannelContext.new(
      "{user_id}-writer-fake",
      channel_class: WriterFakeChannel,
      schema_name: :writer_test
    )
    ctx.parameter(:user_id, schema: {type: :integer})
    ctx.broadcast("Receive writer fake update") do
      operationId "receiveWriterFake"
      message WriterFakeMessage
    end
    AsyncapiCable::Dsl::MetadataStore.register(ctx)
  end

  it "writes one YAML file per configured schema and returns the paths" do
    Dir.mktmpdir do |dir|
      written = described_class.generate_all!(output_dir: dir, format: :yaml)

      expect(written.keys).to eq([:writer_test])
      path = written[:writer_test]
      expect(File).to exist(path)
      expect(path).to end_with(".yaml")

      parsed = YAML.safe_load_file(path, permitted_classes: [Symbol])
      expect(parsed["asyncapi"]).to eq("3.0.0")
      expect(parsed["info"]).to eq("title" => "Cable API", "version" => "0.1.0")
      expect(parsed.dig("channels", "WriterFake", "address")).to eq("{user_id}-writer-fake")
      expect(parsed.dig("operations", "receiveWriterFake", "action")).to eq("receive")
      expect(parsed.dig("components", "schemas", "WriterFakeMessage")).to include("type" => "object")
    end
  end

  it "writes JSON when format: :json" do
    Dir.mktmpdir do |dir|
      written = described_class.generate_all!(output_dir: dir, format: :json)
      path = written[:writer_test]
      expect(path).to end_with(".json")

      parsed = JSON.parse(File.read(path))
      expect(parsed["asyncapi"]).to eq("3.0.0")
    end
  end

  it "raises if no schemas are configured" do
    AsyncapiCable.reset_configuration!
    expect { described_class.generate_all! }.to raise_error(AsyncapiCable::Error, /schemas is empty/)
  end
end
