# Registry reference

The functions a `use UXID.Registry` module defines and the options a `defid`
key accepts. The examples use the `MyApp.IDs` module from
[Declaring a registry](registry.md#declaring-a-registry); the tasks these
serve are in [How to govern prefixes with a registry](registry.md).

## By key - minting and schema configuration

```elixir
MyApp.IDs.generate!(:org)   # => "org_01h..."
MyApp.IDs.prefix(:org)      # => "org"
MyApp.IDs.size(:org)        # => :medium
MyApp.IDs.schema(:org)      # => MyApp.Org
MyApp.IDs.all()             # => [%{key: :org, prefix: "org", schema: MyApp.Org, ...}, ...]
```

`field_opts/1` is the single-source-of-truth hook - a schema spreads it instead
of restating prefix/size/validate anywhere:

```elixir
@primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:org)}
```

`generate!/2` merges caller options over the registry's, so a call site can pass
anything the key does not own:

```elixir
MyApp.IDs.generate!(:share, monotonic: false)   # one-off override
MyApp.IDs.generate!(:export, from: natural_key) # deterministic - see Deterministic keys
```

`:prefix` and `:size` belong to the key and raise if passed - the registry's whole
contract is that a key determines its shape. Drop to `UXID.generate!/1` if you
genuinely need a one-off shape.

## Body-shape options

`:size` is not the only thing that decides what a body looks like. Three more
options can be declared on the key, for the same reason: they change the ID's
shape, so every call site and every schema field has to agree on them.

```elixir
defid :event,   prefix: "evt", size: :small, monotonic: true
defid :session, prefix: "ses", compact_time: true
defid :item,    prefix: "itm", rand_size: 4
```

| Option | Values | Effect |
|---|---|---|
| `:monotonic` | `true`, `false`, a list of sizes | Opts the key into (or out of) [monotonic generation](monotonic.md) without consulting the global policy |
| `:compact_time` | `true`, `false` | Spends 40 rather than 48 bits on the timestamp, moving the freed byte into the random field |
| `:rand_size` | a non-negative integer | An explicit random-byte count, overriding the width implied by `:size` |

Leave one unset and the key defers to the global application configuration
exactly as `UXID.generate!/1` does, so declaring nothing changes nothing. Set it
and it flows into **both** `generate!/2` and `field_opts/1` - so an Ecto
`autogenerate: true` field mints the same shape as an explicit call, with the
declaration living in one place:

```elixir
@primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:event)}
```

A call site can still override any of the three for a one-off
(`generate!(:event, monotonic: false)`); unlike `:prefix` and `:size` they are
defaults, not pins.

Registry-wide defaults are available for the two policy-shaped ones, alongside
`:default_size` and `:default_validate`:

```elixir
use UXID.Registry,
  default_size: :medium,
  default_monotonic: [:small, :medium],
  default_compact_time: false
```

Malformed values are compile errors, like everything else the registry checks: an
unknown size (in `:size` or in a `:monotonic` list) would otherwise fall through
to `:xlarge` and silently mint the wrong shape. Declaring both
`deterministic: true` and `monotonic: true` is rejected too - the pair can never
mint, since one asks for a stable hash and the other for burst-random bits.

## By ID string - the runtime routing table

This is the "which resource is this?" map that powers authorization scans, admin
tooling, and global-ID resolution:

```elixir
MyApp.IDs.known?("org_01h...")      # => true   (cheap prefix-only membership check)
MyApp.IDs.key_for("org_01h...")     # => :org
MyApp.IDs.schema_for("org_01h...")  # => MyApp.Org
MyApp.IDs.resolve("org_01h...")     # => %{key: :org, schema: MyApp.Org, category: :account, ...}
```

Lookups split an ID on the **last** delimiter, which is unambiguous without any
registry lookup because a UXID body is Crockford Base32 and never contains the
delimiter - so `in_ref_01h...` recovers the `in_ref` prefix cleanly. For that
reason the `:delimiter` must be a character that cannot appear in a Base32 body
(`"_"` - the default - or `"-"`); an underscore is preferred for compound
prefixes since it does not break double-click-to-select-the-whole-id.
