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

# A public resource and the richer admin variant documented under the same
# component_name — the openapi-ruby pattern a closure walk has to disambiguate.
module ClosurePublicApi
  class ShadowedResource
    include OpenapiRuby::Components::Base

    component_scopes :closure_public

    schema({type: :object, properties: {name: {type: :string}}})
  end

  class PublicReferrer
    include OpenapiRuby::Components::Base

    component_scopes :closure_public

    schema({
      type: :object,
      properties: {resource: {"$ref": "#/components/schemas/ShadowedResource"}}
    })
  end
end

module ClosureAdminApi
  class ShadowedResource
    include OpenapiRuby::Components::Base

    component_scopes :closure_admin

    schema({
      type: :object,
      properties: {name: {type: :string}, secret: {type: :string}}
    })
  end
end

# Carries both scopes, the way a shared component does.
module ClosureSharedApi
  class SharedReferrer
    include OpenapiRuby::Components::Base

    component_scopes :closure_public, :closure_admin

    schema({
      type: :object,
      properties: {resource: {"$ref": "#/components/schemas/ShadowedResource"}}
    })
  end
end

module ClosureNeutralApi
  class NeutralReferrer
    include OpenapiRuby::Components::Base

    component_scopes :closure_neutral

    schema({
      type: :object,
      properties: {resource: {"$ref": "#/components/schemas/ShadowedResource"}}
    })
  end

  class SpecificVariant
    include OpenapiRuby::Components::Base

    component_scopes :closure_tie

    schema({type: :object})
  end

  class BroadVariant
    include OpenapiRuby::Components::Base

    component_scopes :closure_tie, :closure_extra

    schema({type: :object})
  end
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

    it "resolves a shadowed name to the variant sharing the referrer's scope" do
      registry = [
        ClosurePublicApi::PublicReferrer,
        ClosureAdminApi::ShadowedResource,
        ClosurePublicApi::ShadowedResource
      ]

      expanded = described_class.expand([ClosurePublicApi::PublicReferrer], registry: registry)

      expect(expanded).to include(ClosurePublicApi::ShadowedResource)
      expect(expanded).not_to include(ClosureAdminApi::ShadowedResource)
    end

    it "falls back to the document scope when the referrer shares none" do
      registry = [
        ClosureNeutralApi::NeutralReferrer,
        ClosurePublicApi::ShadowedResource,
        ClosureAdminApi::ShadowedResource
      ]

      expanded = described_class.expand(
        [ClosureNeutralApi::NeutralReferrer],
        scope: :closure_admin,
        registry: registry
      )

      expect(expanded).to include(ClosureAdminApi::ShadowedResource)
      expect(expanded).not_to include(ClosurePublicApi::ShadowedResource)
    end

    it "raises rather than picking a shadowed variant by registration order" do
      registry = [
        ClosureNeutralApi::NeutralReferrer,
        ClosurePublicApi::ShadowedResource,
        ClosureAdminApi::ShadowedResource
      ]

      expect { described_class.expand([ClosureNeutralApi::NeutralReferrer], registry: registry) }
        .to raise_error(AsyncapiCable::Error, /Ambiguous \$ref .*ShadowedResource/)
    end
  end

  describe ".resolve" do
    it "prefers the scope-specific variant over a multi-scope one" do
      candidates = {
        "TieVariant" => [ClosureNeutralApi::BroadVariant, ClosureNeutralApi::SpecificVariant]
      }

      resolved = described_class.resolve(
        "TieVariant",
        candidates,
        referrer: ClosureNeutralApi::NeutralReferrer,
        prefer: [:closure_tie]
      )

      expect(resolved).to eq(ClosureNeutralApi::SpecificVariant)
    end

    # A shared component carrying both scopes shares one with either variant,
    # so it cannot settle the name on its own.
    it "lets the document scope decide when the referrer shares a scope with both" do
      candidates = {
        "ShadowedResource" => [
          ClosureAdminApi::ShadowedResource,
          ClosurePublicApi::ShadowedResource
        ]
      }

      resolved = described_class.resolve(
        "ShadowedResource",
        candidates,
        referrer: ClosureSharedApi::SharedReferrer,
        prefer: [:closure_public]
      )

      expect(resolved).to eq(ClosurePublicApi::ShadowedResource)
    end
  end
end
