require "spec_helper"

RSpec.describe "AsyncapiCable schemas endpoint", type: :request do
  let(:fixture_dir) { File.expand_path("../fixtures/asyncapi", __dir__) }

  before do
    AsyncapiCable.reset_configuration!
    AsyncapiCable.configure do |c|
      c.schemas = {cable_internal: {component_scope: :cable_internal}}
      c.schema_output_dir = fixture_dir
      c.schema_output_format = :yaml
    end
  end

  after { AsyncapiCable.reset_configuration! }

  describe "GET /asyncapi_cable/schemas" do
    it "lists the configured schema names as JSON" do
      get "/asyncapi_cable/schemas"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq("schemas" => ["cable_internal"])
    end
  end

  describe "GET /asyncapi_cable/schemas/:id" do
    it "serves the generated document as YAML" do
      get "/asyncapi_cable/schemas/cable_internal"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/x-yaml")
      expect(response.body).to eq(File.read(File.join(fixture_dir, "cable_internal.yaml")))
    end

    it "returns 404 for a schema name that is not configured" do
      get "/asyncapi_cable/schemas/cable_unknown"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the configured schema has no generated file on disk" do
      AsyncapiCable.configure { |c| c.schema_output_dir = File.expand_path("../fixtures/does-not-exist", __dir__) }

      get "/asyncapi_cable/schemas/cable_internal"

      expect(response).to have_http_status(:not_found)
    end
  end
end
