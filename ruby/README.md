# AsyncapiCable

AsyncAPI 3 documentation and runtime payload validation for Rails ActionCable channels. Pairs with `openapi-ruby`: cable-only schemas share the same `OpenapiRuby::Components::Base` registry as REST schemas, so a single JSON Schema 2020-12 component can flow into both the OpenAPI document and the AsyncAPI document.

## Why

OpenAPI 3.1 still has no native WebSocket support. AsyncAPI 3 does, and uses JSON Schema 2020-12 by default — the same schema dialect `openapi-ruby` already produces. AsyncapiCable bridges the two: declare a channel via a familiar RSpec/Minitest DSL, point it at a component class, and you get both a publishable AsyncAPI 3 document and an in-process broadcast validator from the same source of truth.

## Quick start

Add the gem to the host Gemfile:

```ruby
gem "asyncapi_cable"
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

`FRAMEWORK=` selects which DSL adapters are installed — `rspec`, `minitest`, or
`hybrid` for a suite holding both during a migration. It defaults to what the
host's directory layout says (`spec/rails_helper.rb` and/or
`test/test_helper.rb` present), and `PATTERN` defaults to that framework's
files. Both are usually worth spelling out in a wrapper script, since
declarations live in a known subdirectory:

```sh
FRAMEWORK=hybrid bundle exec rake asyncapi_cable:generate \
  PATTERN="spec/asyncapi/**/*_spec.rb, test/asyncapi/**/*_test.rb"
```

Generation runs in a subprocess with the host's environment set to `test`. The
declaration files are loaded for their `channel` blocks and never executed:
openapi-ruby's `AutorunSuppressor` keeps the `at_exit` hook that runs a suite
from being registered, and its `TestSchemaSuppressor` keeps
`maintain_test_schema!` from demanding a database. Nothing in a document comes
from the database, so generation needs none.

A host test helper can skip its test-time setup during such a run:

```ruby
# test/test_helper.rb
unless AsyncapiCable.schema_generating?
  require "rails/test_help"
end
```

The subprocess also sets openapi-ruby's `OPENAPI_RUBY_GENERATING`, so a helper
already guarding on `OpenapiRuby.schema_generating?` needs no second guard.
Guarding is optional per helper: a helper whose constants are referenced at
declaration-file *load* time must stay unguarded — narrow `PATTERN` instead.

`PATTERN` matching nothing is an error rather than a no-op, so a typo in a glob
can't quietly leave the committed documents untouched.

## Runtime validation

When `config.validation_mode` is not `:disabled`, the engine prepends a hook into `ActionCable::Server::Broadcasting#broadcast` that validates each payload against the **committed AsyncAPI document** (`Runtime::ContractRegistry` parses and memoizes `asyncapi/<schema>.yaml`) for any channel whose stream address matches. The specs + generator are the *write* side of the contract; the runtime only *reads* the committed artifact — so validation works in every process that broadcasts (Minitest, dev server), not just where the RSpec DSL happened to load. A channel that isn't in the generated doc is invisible to runtime validation until `rake asyncapi_cable:generate` output is committed.

| Mode | Behaviour |
|------|-----------|
| `:disabled` (default) | hook is a no-op; broadcasts pass through untouched |
| `:warn_only` | mismatches log a warning via `Rails.logger` (or `STDOUT` outside Rails); broadcast still delivers |
| `:enabled` | mismatches raise `AsyncapiCable::Error`; broadcast does not deliver |

An operation's `messages` are treated as alternatives per AsyncAPI 3 — a payload satisfying *any* declared message passes; mismatches surface the closest match's errors only.

`assert_asyncapi_broadcast` (see Quick start) validates against the *declared* message classes instead — the write side — so a spec documenting a brand-new channel can prove its payloads before the YAML artifact exists.

## Broadcast objects, not serialized strings

`ActionCable.server.broadcast` encodes what you hand it. Hand it a String that
is already JSON and the wire carries a JSON string *literal* — the client parses
twice, `contentSchema` becomes the only honest way to describe the shape, and
validation can say no more than "it is a string".

The pattern is easy to arrive at without choosing it, because the usual way to
render a payload returns a String:

```ruby
# Encodes twice: `to_json` renders, ActionCable escapes the result
WidgetChannel.broadcast_to(user, widget.to_json)
```

Two costs worth knowing. Escaping every `"` as `\"` inflated a 1.2 KB payload by
**12.4%**, paid on every message — worst on the high-frequency channels. And the
double encoding is what makes `assert_asyncapi_broadcast` report `value at root
is not an object`, which reads like a schema problem and is not one; both that
failure and the `:warn_only` log now name the cause.

If a renderer only returns Strings, parse once on the way out — a jbuilder host
might pair `to_jbuilder_json` with:

```ruby
def to_jbuilder_hash(*_args)
  JSON.parse(to_jbuilder_json)
end
```

That parse is cheap next to the render it follows (0.3% of it, measured on the
same payload), and it buys a message schema that describes the object itself:
`message ::V1::Schemas::Widgets::Widget` rather than a string wrapping one.

A String payload is still the right answer when the transport genuinely carries
an opaque representation — one rendered elsewhere, cached as text, or signed.
That is what `contentMediaType` and `contentSchema` are for, and such a message
validates without complaint.

## Which components land in a document

A document's **entry points** are what `component_scope` selects *plus every
message a channel declares*, and each entry point brings the transitive closure
of everything it `$ref`s. Scope is not a fence around the document.

The declared messages matter on their own: the most natural way to describe a
channel that broadcasts a rendered REST resource is to point straight at the
component that already describes it, and that component carries no cable scope.

```ruby
channel "widgets:{user_gid}", channel_class: WidgetChannel do
  broadcast "A widget the user owns changed" do
    message ::V1::Schemas::Widgets::Widget   # scope :v1
  end
end
```

That matters as soon as a message describes an embedded payload by pointing at
an existing component — say a presence broadcast whose `payload` string carries
a rendered REST representation:

```ruby
payload: {
  type: :string,
  contentMediaType: "application/json",
  contentSchema: {"$ref": "#/components/schemas/WordCloud"}
}
```

`WordCloud` is a REST component and carries no cable scope. Including the
message without it would write a pointer that resolves to nothing, and
`@asyncapi/parser` rejects the whole document (`'#/components/schemas/X' does
not exist`). So the writer follows the reference and brings it along, together
with anything it references in turn. A name that matches no registered
component is left as written — the document then fails to parse, which is the
right outcome for a typo.

Runtime validation resolves components the same way, so a payload that passes
`assert_asyncapi_broadcast` passes against the committed document too.

### Shadowed component names

A `component_name` is only unique within a scope. openapi-ruby hosts routinely
document a richer admin variant of a public resource under the same name, and
`to_openapi_hash` never meets the collision because it filters by scope before
indexing by name. A closure walk has no such filter, so it has to say which
variant a pointer meant — picking by registration order would write a document
that parses cleanly and describes the wrong contract.

A `$ref` means what it means in the referring component's own document, so the
candidate sharing a scope with the referrer wins. Failing that the document's
own scope decides, then openapi-ruby's specificity rule (a scope-specific
component beats a multi-scope one). A name still undecided after all three is a
real ambiguity and raises, naming the candidates:

```
Ambiguous $ref #/components/schemas/Widget from Cable::V1::Schemas::WidgetMessage:
V1::Schemas::Widgets::Widget [:v1], Admin::V1::Schemas::Widgets::Widget [:admin].
Give the intended component a scope the referrer shares, or name the variants distinctly.
```

## Snake_case wire format

The AsyncAPI doc is written from the raw schema definitions, not the camelized `OpenapiRuby::Components::Loader` projection. This is deliberate: ActionCable broadcasts are snake_case in the wild, so the cable document describes the actual wire shape rather than the REST-style camelCase view of the same component. Both the writer and the runtime validator follow the same convention.

## Developing the gem

The gem lives in `ruby/` of the [asyncapi-cable](https://github.com/openapi-ruby/asyncapi-cable)
repository, alongside the npm generator that turns the documents this gem
writes into typed cable clients.

```sh
cd ruby
bundle install
bundle exec rspec
bundle exec standardrb
```

Specs run against the dummy Rails app in `spec/dummy`. No Gemfile.lock is
committed (gem convention), so a run resolves against the current gems.

## License

MIT.
