---
theme: none
title: asyncapi_cable
info: A typed contract for your ActionCable broadcasts — docs, tests & runtime validation, in Rails.
class: lcars
highlighter: shiki
lineNumbers: false
canvasWidth: 1920
fonts:
  sans: Barlow
  mono: JetBrains Mono
  # Antonio used for headings via CSS below
drawings:
  persist: false
transition: fade
mdc: true
---


<!-- Reusable LCARS frame, repeated on every slide. The readout is live via
     $slidev.nav (mdc: true renders the Vue expression). canvasWidth is 1920, so
     the px sizes below are authored against a 1920x1080 canvas. -->

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Ruby Usergroup // Engineering Briefing · Pt. 2</div>
<div style="font-family:'JetBrains Mono',monospace;font-weight:700;font-size:140px;line-height:0.92;color:var(--cream);letter-spacing:-2px;">asyncapi_cable</div>
<div class="sub" style="margin-top:34px;max-width:1180px;line-height:1.3;">A typed contract for your ActionCable broadcasts — docs, tests &amp; runtime validation, in Rails.</div>
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;margin-top:44px;">v0.1 · MIT · AsyncAPI 3 · Ruby ≥ 3.2 · Rails ≥ 7</div>

<!--
Hook — a companion to the openapi_ruby talk. Show of hands: who's got an ActionCable channel where the frontend and the server quietly disagree about what's in the payload? Right. WebSockets are the one corner of a Rails app with no typed contract. This is asyncapi_cable: docs, tests, and runtime validation for your broadcasts, sharing the exact same schema components as your REST API.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Personnel // Speaker</div>
<h1 class="lc hl">Marten Klitzke</h1>
<div class="sub" style="margin-top:18px;">Software Engineer · fobizz</div>
<div style="display:flex;gap:60px;margin-top:56px;font-family:'JetBrains Mono',monospace;font-size:24px;">
  <div><span class="steel">web&nbsp;&nbsp;&nbsp;&nbsp;</span> <a href="https://marten.klitzke.xyz" style="color:var(--teal);">marten.klitzke.xyz</a></div>
  <div><span class="steel">github&nbsp;</span> <a href="https://github.com/mortik" style="color:var(--teal);">@mortik</a></div>
</div>

<!--
Same as last time — I'm Marten, engineer at fobizz. We're a Rails shop, edtech, and we push a lot over WebSockets: job progress, live previews, generated material landing in the UI. That firehose is exactly where this gem came from.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Diagnostic // payload drift</div>
<h1 class="lc title">The channel sends one thing, the client expects another</h1>

<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:26px;margin-top:40px;align-items:stretch;">
<div style="display:flex;flex-direction:column;gap:12px;">
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;">app/jobs/generate_job.rb</div>

```ruby
broadcast_status(
  user, "running",
  stage: "encoding"
)
```

<div class="small">what the server sends</div>
</div>
<div style="display:flex;flex-direction:column;gap:12px;">
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;">the contract · nowhere</div>
<div class="void" style="flex:1;">
<div class="small coral" style="font-family:'JetBrains Mono',monospace;line-height:1.6;letter-spacing:1px;">— no doc —<br>— no schema —<br>— no test —</div>
</div>
<div class="small">what enforces agreement</div>
</div>
<div style="display:flex;flex-direction:column;gap:12px;">
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;">frontend/types.ts</div>

```ts
received(d) {
  d.progress // undefined
}
```

<div class="small">what the client reads</div>
</div>
</div>

<div class="cap cream" style="margin-top:28px;">Everything's green. The progress bar just quietly stopped moving.</div>

<!--
Here's the drift, WebSocket edition. A job broadcasts a status message — say it drops the user_id or renames a field. The Vue frontend hand-casts that payload to a TypeScript interface it wrote by hand months ago. Nothing sits between them: no doc, no test on the broadcast body. The types compile, the job's tests pass, the socket delivers — and the moment the shape changes, the frontend silently reads undefined and a progress bar just stops moving. Nobody gets notified that the channel started sending different data.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="display:flex;align-items:center;gap:70px;height:100%;">
<div style="flex:1;">
<div class="eyebrow">Primer // 101</div>
<h1 class="lc hl">OpenAPI —<br>but for messages.</h1>
<div class="cap" style="margin-top:30px;max-width:520px;line-height:1.35;">Same <span class="teal" style="font-family:'JetBrains Mono',monospace;">JSON&nbsp;Schema&nbsp;2020-12</span> as OpenAPI 3.1. Channels instead of paths.</div>
</div>
<div style="flex:1.05;">

```yaml
channels:
  UserJobStatus:
    address: '{user_id}-user-job-status'
    messages:
      status:
        $ref: '#/components/messages/JobStatus'

operations:
  onJobStatus:
    action: receive
```

</div>
</div>

<!--
Quick 101. AsyncAPI is OpenAPI's sibling for message-driven APIs — same idea, but for things that arrive over a socket instead of a request/response. You describe channels, operations, and the message payloads. The nice part for us: AsyncAPI 3 speaks JSON Schema 2020-12, exactly the same schema dialect OpenAPI 3.1 uses. So a payload shape you've already defined for REST can describe a broadcast too. Watch the $ref into components — that's the seam we're going to share.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Survey // the landscape</div>
<h1 class="lc title">Typing a WebSocket on Rails: your options</h1>

<div style="display:grid;grid-template-columns:1fr 1fr;gap:26px;margin-top:40px;">
  <div class="card"><div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;">01</div><div style="font-family:'Antonio',sans-serif;font-weight:600;text-transform:uppercase;letter-spacing:1px;font-size:40px;color:var(--cream);margin:8px 0;">Cast &amp; pray</div><div class="small"><code>as SomeType</code> on the client.</div></div>
  <div class="card"><div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;">02</div><div style="font-family:'Antonio',sans-serif;font-weight:600;text-transform:uppercase;letter-spacing:1px;font-size:40px;color:var(--cream);margin:8px 0;">Hand-write TS</div><div class="small">Two sources, kept in sync by hope.</div></div>
  <div class="card"><div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;">03</div><div style="font-family:'Antonio',sans-serif;font-weight:600;text-transform:uppercase;letter-spacing:1px;font-size:40px;color:var(--cream);margin:8px 0;">Ad-hoc JSON Schema</div><div class="small">Checks scattered, never docs.</div></div>
  <div class="card here"><div class="small gold" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;">04 · you are here</div><div style="font-family:'Antonio',sans-serif;font-weight:600;text-transform:uppercase;letter-spacing:1px;font-size:40px;color:var(--gold);margin:8px 0;">Generate from tests</div><div class="small">AsyncAPI 3 · what OpenAPI can't do.</div></div>
</div>

<!--
How do people type a WebSocket on Rails today? Mostly they don't. Option one: cast the payload on the frontend and pray. Two: hand-write TypeScript interfaces and hope somebody updates them when the Ruby changes. Three: scatter ad-hoc JSON Schema checks around. And the honest gap — OpenAPI 3.1, which we already use for REST, has no native WebSocket support at all. AsyncAPI 3 does. That's the last card, and it's where this gem lives: generate the contract from tests, same as openapi_ruby.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="font-family:'JetBrains Mono',monospace;font-weight:700;font-size:110px;line-height:0.92;color:var(--cream);letter-spacing:-2px;">asyncapi_cable</div>
<div class="cap steel" style="margin-top:20px;">Same shape as its REST sibling. One engine. Three jobs.</div>
<div style="display:flex;gap:26px;margin-top:48px;">
  <div class="card" style="flex:1;border-top:4px solid var(--gold);"><div style="font-family:'JetBrains Mono',monospace;font-size:40px;color:var(--gold);">01</div><div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:2px;font-size:40px;color:var(--cream);margin-top:8px;">Components</div><div class="small" style="margin-top:10px;">Shared schema classes.</div></div>
  <div class="card" style="flex:1;border-top:4px solid var(--teal);"><div style="font-family:'JetBrains Mono',monospace;font-size:40px;color:var(--teal);">02</div><div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:2px;font-size:40px;color:var(--cream);margin-top:8px;">Generation</div><div class="small" style="margin-top:10px;">Doc from channel tests.</div></div>
  <div class="card" style="flex:1;border-top:4px solid var(--coral);"><div style="font-family:'JetBrains Mono',monospace;font-size:40px;color:var(--coral);">03</div><div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:2px;font-size:40px;color:var(--cream);margin-top:8px;">Validation</div><div class="small" style="margin-top:10px;">Runtime broadcast hook.</div></div>
</div>

<!--
So — asyncapi_cable. Same shape as its REST sibling: one engine, three jobs. Components: the message schemas, and crucially they're the same Ruby classes openapi_ruby already uses. Generation: the AsyncAPI doc comes out of channel tests. Validation: a runtime hook that checks every broadcast against the contract. All three read one definition through one engine — json_schemer — the same engine openapi_ruby uses. That's the whole trick: nothing new to learn, and REST and WebSocket share a spine.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="display:flex;align-items:center;gap:70px;height:100%;">
<div style="flex:0.85;">
<div class="eyebrow">Subsystem 01 // components</div>
<h1 class="lc hl">The same schema<br>classes as REST</h1>
<div class="cap" style="margin-top:28px;max-width:440px;line-height:1.35;">One <span class="teal" style="font-family:'JetBrains Mono',monospace;">Components::Base</span>. A scope tag picks the doc.</div>
</div>
<div style="flex:1.15;">

```ruby
class Schemas::CurrentUserJobStatusMessage
  include OpenapiRuby::Components::Base
  component_scopes :cable_internal

  schema type: :object do
    property :action,  JobStatusActionEnum
    property :user_id, :string
    property :status,  :string
    required :action, :user_id, :status
  end
end
```

</div>
</div>

<!--
Subsystem one, and it's the punchline of the whole gem: components are not new. A cable message is the same OpenapiRuby::Components::Base class your REST API already defines. The only new thing is a scope tag — component_scopes :cable_internal — that says which document this schema belongs in. Because AsyncAPI 3 and OpenAPI 3.1 both speak JSON Schema 2020-12, one class can legitimately be the source of truth for a REST response and a WebSocket broadcast at the same time.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Subsystem 01 // scopes</div>
<h1 class="lc title">One definition, two specs</h1>

<div style="display:grid;grid-template-columns:1fr 1fr;gap:30px;margin-top:36px;">
<div>
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">Scope → which document</div>

```ruby
# AsyncAPI doc only
component_scopes :cable_internal

# OpenAPI doc only
component_scopes :internal_v1
```

</div>
<div class="tealrail">
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">Dual-scope → both, one source</div>

```ruby
class JobStatusActionEnum
  include Components::Base
  component_scopes :internal_v1,
                   :cable_internal
end
```

</div>
</div>

<!--
Here's what the shared base buys you. Tag a schema :cable_internal and it lands in the AsyncAPI document only. Tag it :internal_v1 and it's REST-only. Dual-scope it and one definition feeds both specs at once — which is exactly what we do for the JobStatusActionEnum, because the cable doc's $ref to it has to resolve in both worlds. One enum, defined once, correct in your REST docs and your WebSocket docs simultaneously. That's the payoff of a shared JSON Schema substrate.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="display:flex;align-items:center;gap:70px;height:100%;">
<div style="flex:0.8;">
<div class="eyebrow">Subsystem 02 // generation</div>
<h1 class="lc hl">The doc comes from<br>channel tests</h1>
<div class="cap" style="margin-top:28px;max-width:420px;line-height:1.35;">Flat <span class="teal">channel</span> declaration — same shape as REST's <span style="font-family:'JetBrains Mono',monospace;">api_path</span>.</div>
</div>
<div style="flex:1.2;">

```ruby
describe CurrentUserJobStatusChannel,
         type: :asyncapi do
  channel '{user_id}-user-job-status' do
    parameter :user_id, :string
    broadcast 'onJobStatus' do
      message CurrentUserJobStatusMessage
    end
  end
end
```

</div>
</div>

<!--
Subsystem two: generation, and if you saw the openapi_ruby talk this will look familiar on purpose. You declare a channel in a test — flat, just like the api_path style — give it the stream address with its parameter, and say this broadcast operation carries this message. That declaration is the source for the AsyncAPI doc. Same mental model as the REST side; a reader who knows one knows both.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="display:flex;align-items:center;gap:70px;height:100%;">
<div style="flex:0.8;">
<div class="eyebrow">RSpec or Minitest · same DSL</div>
<h1 class="lc hl">One assert fires it<br>and checks it</h1>
<div class="cap" style="margin-top:28px;max-width:420px;line-height:1.35;">Triggers the real broadcast · validates every captured payload.</div>
</div>
<div style="flex:1.2;">

```ruby
it 'broadcasts job status' do
  assert_asyncapi_broadcast(
    params: { user_id: user.id }
  ) do
    GenerateJob.perform_now(user)
  end
end
```

</div>
</div>

<!--
And just like the REST side's assert_api_response, the declaration comes with an executable assert. assert_asyncapi_broadcast takes the params that fill the stream address and a block that triggers the real work. It performs the actual broadcast, captures every payload on that stream, asserts at least one arrived, and validates each against the declared message schema. Only broadcasts are observable this way — subscribe and publish are client-side — so the helper is broadcast-specific by design. RSpec or Minitest, identical surface.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Subsystem 02 // output</div>
<h1 class="lc title">Test in, doc out</h1>

<div style="display:grid;grid-template-columns:1fr 44px 1fr;gap:18px;margin-top:36px;align-items:center;">
<div>
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">The channel test · Ruby</div>

```ruby
broadcast 'onJobStatus' do
  message CurrentUserJobStatusMessage
end
```

</div>
<div style="font-family:'Antonio',sans-serif;font-size:52px;color:var(--gold);text-align:center;">→</div>
<div class="tealrail">
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">Generated · AsyncAPI YAML</div>

```yaml
onJobStatus:
  action: receive
  messages:
    - $ref: '#/.../CurrentUserJobStatusMessage'
```

</div>
</div>

<div class="cap cream" style="margin-top:26px;">Produced by <span class="teal" style="font-family:'JetBrains Mono',monospace;">rake asyncapi_cable:generate</span> — CI fails on drift, just like <span style="font-family:'JetBrains Mono',monospace;">./swagger</span>.</div>

<!--
Same picture as the REST talk, WebSocket edition. Left: the channel test you wrote. Right: the AsyncAPI it generates — the operation with action receive, the message, and CurrentUserJobStatusMessage resolved to a clean $ref into components. Zero YAML by hand. It's produced by an explicit rake task, and — this is the part I like — CI diffs the committed asyncapi folder, exactly like it already diffs the swagger folder for REST. If the spec and the doc disagree, the build goes red. Docs can't rot.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="display:flex;align-items:center;gap:70px;height:100%;">
<div style="flex:0.9;">
<div class="eyebrow">Subsystem 03 // validation</div>
<h1 class="lc hl">Every broadcast,<br>checked</h1>
<div class="small steel" style="font-family:'JetBrains Mono',monospace;margin-top:26px;line-height:1.7;">:enabled&nbsp;&nbsp;|&nbsp;&nbsp;:warn_only&nbsp;&nbsp;|&nbsp;&nbsp;:disabled</div>
<div class="cap cream" style="margin-top:24px;line-height:1.4;">bad broadcast → <span class="coral">fails the test</span><br>undocumented stream → <span class="teal">skipped</span></div>
</div>
<div style="flex:1.1;">

```ruby
AsyncapiCable.configure do |c|
  c.validation_mode =
    if Rails.env.test?           then :enabled
    elsif Rails.env.development? then :warn_only
    else :disabled
    end
end
```

</div>
</div>

<!--
Subsystem three: enforce it at runtime. A hook prepends into ActionCable's broadcasting path and checks every outgoing payload against the committed contract. The mode is per-environment: enabled in test, so a drifted broadcast fails the suite; warn_only in dev, so you see it in the logs without wedging local work; disabled in production until every broadcast site is proven covered. And a stream that isn't under contract yet is simply skipped — you adopt it channel by channel. This is the piece REST never needed, because openapi_ruby only generates docs; a live socket actually has to be policed.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Subsystem 03 // freebies</div>
<h1 class="lc title">The same contract types your frontend</h1>

<div style="display:grid;grid-template-columns:1fr 1fr;gap:30px;margin-top:36px;">
<div>
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">Generated typed composable · Vue</div>

```ts
const ch = useCurrentUserJobStatusChannel({
  onJobStatus(msg) {
    // msg.progress: number
  }
})
```

</div>
<div>
<div class="small steel" style="font-family:'JetBrains Mono',monospace;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">One generator · web + native</div>

```bash
# npm: asyncapi-cable
$ asyncapi-cable -c cable.config

# preset: vue | react
# classes on @anycable/core
```

</div>
</div>

<!--
And here's the freebie that closes the loop back to that opening problem. The same committed YAML feeds a frontend generator — published as an npm package, asyncapi-cable — that emits typed message interfaces and a typed subscription composable straight into the Vue app. No hand-written interface to drift out of sync. The generated channel classes sit on @anycable/core, so the same types compile on React Native too. Define the payload once in Ruby; the web and mobile clients get their types for free.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div class="eyebrow">Diagnosis // resolved</div>
<div style="display:flex;flex-direction:column;gap:28px;margin-top:20px;">
  <div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:2px;font-size:70px;color:var(--gold);line-height:1;">Define the payload once.</div>
  <div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:2px;font-size:70px;color:var(--gold);line-height:1;">Same schema in tests, runtime &amp; frontend.</div>
  <div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:2px;font-size:70px;color:var(--gold);line-height:1;">Docs are your passing channel tests.</div>
</div>
<div class="cap steel" style="margin-top:46px;">Three views of one definition — same json_schemer engine as your REST contract.</div>

<!--
Same payoff as the REST talk, and it stacks on top of it. Define the broadcast payload once — as a Ruby schema class. The same schema validates it in your tests, at runtime on the live socket, and generates the frontend's types. Your docs are literally your passing channel tests. Docs, runtime, and the client are three views of one definition — and json_schemer is the shared engine underneath, the very same engine your REST contract already runs on. One spine, both protocols.
-->

---

<div class="lcars-frame">
  <div class="elbow"></div>
  <div class="rail"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="topbar"><div class="tag">ASYNCAPI-CABLE</div><div class="s1"></div><div class="fill"></div><div class="s2"></div><div class="readout">NCC · SEC {{ ($slidev.nav.currentPage).toString().padStart(2,"0") }}/{{ $slidev.nav.total }}</div></div>
  <div class="botbar"><div class="b1"></div><div class="lab">ENGINEERING</div><div class="fill"></div><div class="b2"></div><div class="b3"></div></div>
</div>

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;">
<div style="font-family:'Antonio',sans-serif;font-weight:700;text-transform:uppercase;letter-spacing:3px;font-size:180px;color:var(--cream);line-height:0.9;">Thank you</div>
<div style="font-family:'Antonio',sans-serif;font-weight:600;text-transform:uppercase;letter-spacing:4px;font-size:88px;color:var(--teal);margin-top:24px;">Questions?</div>
</div>

<!--
That's asyncapi_cable. Thank you — questions?
-->
