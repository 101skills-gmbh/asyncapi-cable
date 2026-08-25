require "spec_helper"
require "openapi_ruby"

class ClosureLeafEnum
  include OpenapiRuby::Components::Base

  component_scopes :closure_rest

  schema({type: :string, enum: %w[a b]})
end

class ClosureNestedComponent
  include OpenapiRuby::Components::Base

  component_scopes :closure_rest

  schema({
    type: :object,
    properties: {kind: {"$ref": "#/components/schemas/ClosureLeafEnum"}}
  })
end

class ClosureEntryComponent
  include OpenapiRuby::Components::Base

  component_scopes :closure_cable

  schema({
    type: :object,
    properties: {
      payload: {
        type: :string,
        contentSchema: {"$ref": "#/components/schemas/ClosureNestedComponent"}
      }
    }
  })
end

class ClosureSelfReferentialComponent
  include OpenapiRuby::Components::Base

  component_scopes :closure_cable

  schema({
    type: :object,
    properties: {child: {"$ref": "#/components/schemas/ClosureSelfReferentialComponent"}}
  })
end

RSpec.describe AsyncapiCable::Components::ReferenceClosure do
  describe ".referenced_names" do
    it "finds refs at any depth" do
      definition = {"properties" => {"a" => {"items" => [{"$ref" => "#/components/schemas/Deep"}]}}}

      expect(described_class.referenced_names(definition)).to eq(["Deep"])
    end

    it "ignores pointers that are not schema components" do
      definition = {"payload" => {"$ref" => "#/components/messages/NotASchema"}}

      expect(described_class.referenced_names(definition)).to be_empty
    end

    it "reports each name once" do
      definition = {
        "a" => {"$ref" => "#/components/schemas/Twice"},
        "b" => {"$ref" => "#/components/schemas/Twice"}
      }

      expect(described_class.referenced_names(definition)).to eq(["Twice"])
    end
  end

  describe ".expand" do
    it "pulls in a referenced component from another scope, transitively" do
      expanded = described_class.expand([ClosureEntryComponent])

      expect(expanded.map(&:component_name))
        .to contain_exactly("ClosureEntryComponent", "ClosureNestedComponent", "ClosureLeafEnum")
    end

    it "keeps the entry points themselves" do
      expect(described_class.expand([ClosureEntryComponent])).to include(ClosureEntryComponent)
    end

    it "terminates on a self-reference" do
      expect(described_class.expand([ClosureSelfReferentialComponent]).map(&:component_name))
        .to eq(["ClosureSelfReferentialComponent"])
    end

    it "leaves an unresolvable ref alone rather than raising" do
      expect { described_class.expand([ClosureEntryComponent], registry: [ClosureEntryComponent]) }
        .not_to raise_error
    end
  end
end
