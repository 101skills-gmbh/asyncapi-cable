# Loaded by DeclarationLoader specs to prove a Minitest-DSL declaration is
# collected. Deliberately not named `*_spec.rb` / `*_test.rb` so neither
# framework's default pattern picks it up on its own.
require "openapi_ruby"
require "asyncapi_cable/minitest"

class DeclarationLoaderFixtureChannel
end

class DeclarationLoaderFixtureMessage
  include OpenapiRuby::Components::Base

  component_scopes :cable

  schema({
    type: :object,
    properties: {action: {type: :string}},
    required: %w[action],
    additionalProperties: false
  })
end

class DeclarationLoaderFixtureTest
  include AsyncapiCable::Adapters::Minitest::DSL

  asyncapi_schema :declaration_loader_fixture

  channel "{user_id}-loader-fixture", channel_class: DeclarationLoaderFixtureChannel do
    parameter :user_id, schema: {type: :integer}

    broadcast "Receive fixture update" do
      operationId "receiveLoaderFixture"
      message DeclarationLoaderFixtureMessage
    end
  end
end
