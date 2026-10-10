# How to tune ID generation

Two settings change how IDs are minted without changing what a call site asks
for: monotonic generation, for bursts of IDs in one millisecond, and a size
floor, for test suites that mint small IDs quickly. Why monotonic mode exists
and what it costs is on
[Why monotonic mode exists and what it costs](monotonic.md); every key below
is listed in the [Configuration](configuration.md) reference.

## Turn on monotonic generation

Per call, for every size or for a list of sizes:

```elixir
# Per-call: on for all sizes
UXID.generate!(size: :small, monotonic: true)

# Per-size list (alias-aware: :small also matches :s, :medium matches :m, ...)
UXID.generate!(size: :small, monotonic: [:small, :medium])
```

**Global policy** (overridable per-call/per-field, mirrors `compact_small_times`):

```elixir
# config/config.exs
config :uxid, monotonic: true
# or only for specific sizes:
config :uxid, monotonic: [:small, :medium]
```

**In Ecto schemas:**

```elixir
field :id, UXID, autogenerate: true, prefix: "evt", size: :small, monotonic: true
```

**On a registry key** - declare it once and both `generate!/2` and `field_opts/1`
carry it, so no call site or schema field can disagree (see
[How to govern prefixes with a registry](registry.md)):

```elixir
defid :event, prefix: "evt", size: :small, monotonic: true

MyApp.IDs.generate!(:event)                   # monotonic
MyApp.IDs.generate!(:event, monotonic: false) # one-off opt-out
```

## Enforce a minimum size in tests

In test environments, code that requests `:small` (or smaller) can generate
enough IDs to hit duplicate-key violations. The `:min_size` config upgrades any
requested size below the floor, without touching larger ones:

```elixir
# config/test.exs
config :uxid, min_size: :medium
```

See the [Configuration guide](configuration.md#min_size) for details.
