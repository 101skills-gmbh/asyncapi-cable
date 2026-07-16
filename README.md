# AsyncapiCable

AsyncAPI 3 documentation and runtime payload validation for Rails ActionCable channels. Pairs with `openapi-ruby`: cable-only schemas share the same `OpenapiRuby::Components::Base` registry as REST schemas, so a single JSON Schema 2020-12 component can flow into both the OpenAPI document and the AsyncAPI document.

## Why

OpenAPI 3.1 still has no native WebSocket support. AsyncAPI 3 does, and uses JSON Schema 2020-12 by default — the same schema dialect `openapi-ruby` already produces. AsyncapiCable bridges the two: declare a channel via a familiar RSpec/Minitest DSL, point it at a component class, and you get both a publishable AsyncAPI 3 document and an in-process broadcast validator from the same source of truth.

## Quick start

Add the gem (or, in-repo, a path entry) to the host Gemfile:

```ruby
gem "asyncapi_cable", path: "engines/asyncapi_cable"
```

Configure one or more cable documents in an initializer. Each entry is one AsyncAPI document and one `component_scope` used to filter `OpenapiRuby::Components::Base` subclasses:

```ruby
# config/initializers/asyncapi_cable.rb
AsyncapiCable.configure do |config|
  config.schemas = {
    cable_internal: {
      info: { title: "My Internal Cable API", version: "v1" },
      servers: {
        dev:  { host: "localhost:3000",   pathname: "/cable", protocol: "ws"  },
        live: { host: "app.example.com",  pathname: "/cable", protocol: "wss" }
      },
      component_scope: :cable_internal
    }
  }
  config.schema_output_dir = "asyncapi"
  config.validation_mode = :disabled # :disabled | :warn_only | :enabled
end
```

Declare a message component using the standard `OpenapiRuby::Components::Base`, scoped to the cable audience:

```ruby
# packs/api_internal/app/components/internal/v1/schemas/job_status_message.rb
class Internal::V1::Schemas::JobStatusMessage
  include OpenapiRuby::Components::Base

  component_scopes :cable_internal

  schema({
    type: :object,
    properties: {
      action: { type: :string },
      user_id: { type: :integer },
      status: { type: :string }
    },
    required: %w[action user_id status]
  })
end
```

Document a channel with the DSL adapter for your test framework. The DSL
mirrors openapi-ruby's Minitest-style surface: a flat class-level `channel`
declaration (no nested example groups), plus plain tests that call
`assert_asyncapi_broadcast` — which runs your triggering code, captures every
broadcast on the resolved stream, and validates each payload against the
declared message schemas:

```ruby
# RSpec — spec/asyncapi/job_status_channel_spec.rb
require "asyncapi_cable/rspec"

RSpec.describe JobStatusChannel, type: :asyncapi do
  asyncapi_schema :cable_internal

  channel "{user_id}-job-status" do
    parameter :user_id, schema: { type: :integer }
    broadcast "Job status updates" do
      operationId "receiveJobStatus"
      message Internal::V1::Schemas::JobStatusMessage
    end
  end

  it "broadcasts a schema-valid payload" do
    payloads = assert_asyncapi_broadcast(params: { user_id: user.id }) do
      SomeJob.perform_now(user)
    end
    expect(payloads.first["action"]).to eq("started")
  end
end
```

```ruby
# Minitest — test/asyncapi/job_status_channel_test.rb
require "asyncapi_cable/minitest"

class JobStatusChannelTest < ActiveSupport::TestCase
  include AsyncapiCable::Adapters::Minitest::DSL

  asyncapi_schema :cable_internal

  channel "{user_id}-job-status", channel_class: JobStatusChannel do
    parameter :user_id, schema: { type: :integer }
    broadcast "Job status updates" do
      operationId "receiveJobStatus"
      message Internal::V1::Schemas::JobStatusMessage
    end
  end

  test "broadcasts a schema-valid payload" do
    payloads = assert_asyncapi_broadcast(params: { user_id: user.id }) do
      SomeJob.perform_now(user)
    end
    assert_equal "started", payloads.first["action"]
  end
end
```

`assert_asyncapi_broadcast` needs the ActionCable test adapter (`adapter: test`
in `config/cable.yml`). It fails the test when no broadcast arrives on the
expanded stream or when a captured payload violates every declared message,
and raises `AsyncapiCable::Error` for usage mistakes — no broadcast operation
declared, or `params` that don't resolve the stream template. It returns the
decoded payloads for follow-up assertions.

Generate the document:

```sh
bundle exec rake asyncapi_cable:generate PATTERN="spec/asyncapi/**/*_spec.rb"
# writes asyncapi/cable_internal.yaml
```

## Runtime validation

When `config.validation_mode` is not `:disabled`, the engine prepends a hook into `ActionCable::Server::Broadcasting#broadcast` that validates each payload against the **committed AsyncAPI document** (`Runtime::ContractRegistry` parses and memoizes `asyncapi/<schema>.yaml`) for any channel whose stream address matches. The specs + generator are the *write* side of the contract; the runtime only *reads* the committed artifact — so validation works in every process that broadcasts (Minitest, dev server), not just where the RSpec DSL happened to load. A channel that isn't in the generated doc is invisible to runtime validation until `rake asyncapi_cable:generate` output is committed.

| Mode | Behaviour |
|------|-----------|
| `:disabled` (default) | hook is a no-op; broadcasts pass through untouched |
| `:warn_only` | mismatches log a warning via `Rails.logger` (or `STDOUT` outside Rails); broadcast still delivers |
| `:enabled` | mismatches raise `AsyncapiCable::Error`; broadcast does not deliver |

An operation's `messages` are treated as alternatives per AsyncAPI 3 — a payload satisfying *any* declared message passes; mismatches surface the closest match's errors only.

`assert_asyncapi_broadcast` (see Quick start) validates against the *declared* message classes instead — the write side — so a spec documenting a brand-new channel can prove its payloads before the YAML artifact exists.

## Snake_case wire format

The AsyncAPI doc is written from the raw schema definitions, not the camelized `OpenapiRuby::Components::Loader` projection. This is deliberate: ActionCable broadcasts are snake_case in the wild, so the cable document describes the actual wire shape rather than the REST-style camelCase view of the same component. Both the writer and the runtime validator follow the same convention.

## Testing the engine itself

```sh
cd engines/asyncapi_cable
bundle install
bundle exec rspec
```

## License

MIT.
