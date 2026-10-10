# How to govern prefixes with a registry

This guide declares one registry module as your app's source of truth for
prefixes, then uses it to mint IDs, route an ID back to its schema, and check
the result in CI. Why a prefix is worth governing at all is in
[The prefix](why-prefix-time-randomness.md#the-prefix-an-id-that-says-what-it-points-at).

## Declaring a registry

Declare one registry module as your single source of truth:

```elixir
defmodule MyApp.IDs do
  use UXID.Registry,
    default_size: :medium,
    default_validate: true

  defid :org,     prefix: "org",     schema: MyApp.Org,             category: :account
  defid :user,    prefix: "usr",     size: :large, schema: MyApp.Accounts.User
  defid :api_key, prefix: "apikey"
  defid :event,   prefix: "evt",     size: :small, monotonic: true
  retired "cus" # reserve a prefix so it stays unique-checked, never reused
end
```

**Compile-time guarantees.** Every prefix is checked against `:prefix_format`
(overridable; the default permits an internal underscore for compound prefixes
like `in_ref`), and all prefixes - active *and* `retired` - are checked for
uniqueness. A malformed or duplicate prefix is a compile error, so the governance
every prefixed-ID scheme needs ships in the library.

Keep to **one registry module per app**: compile-time uniqueness only holds
within a single module, since the library never sees two registries together.

Every function the module now defines (minting by key, `field_opts/1` for a
schema field) and every option a key accepts are in the
[Registry reference](registry-reference.md).

## Deterministic keys

Some entities are derived rather than created: their identity is a function of a
natural key, so the same input must always produce the same ID (see the
[Deterministic IDs guide](deterministic.md)). Mint those by key with `from:`:

```elixir
MyApp.IDs.generate!(:export, from: external_id)
# => "exp_z9r3k..."   (stable for this input, forever)
```

That is the call shape to prefer over `UXID.generate!/1` with `from:`: the
prefix and size still come from the registry (and cannot be overridden), while
`from:` passes through.

Passthrough alone still permits the failure mode where one call site derives and
another mints randomly, silently producing two ID shapes for one entity. Declare
the key so that becomes impossible:

```elixir
defid :export, prefix: "exp", deterministic: true, route: true
```

```elixir
MyApp.IDs.generate!(:export)
# ** (ArgumentError) key :export is declared deterministic: true and must be
#    minted with from: - e.g. generate!(:export, from: natural_key)
```

The flag is a *requirement*, not a permission: an undeclared key can still be
minted with `from:`, so an incidental deterministic ID does not force a registry
change.

**Do not wire a deterministic key with `autogenerate: true`.** Ecto has no
per-row input at autogenerate time, so `UXID` mints a random ID there and the
declaration cannot stop it. Mint in a changeset instead:

```elixir
# NOT this, for a deterministic key:
@primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:export)}

# but this:
@primary_key {:id, UXID, MyApp.IDs.field_opts(:export)}

def changeset(export, attrs) do
  export
  |> cast(attrs, [:external_id])
  |> put_change(:id, MyApp.IDs.generate!(:export, from: attrs.external_id))
end
```

The flag is surfaced on `all/0`, so an app can enforce that rule over its own
registry in a conformance test.

One sizing note: a deterministic body spends its whole width on hash bits, and a
key with no `:size` (and no registry `:default_size`) falls through to the
**`:xlarge`** width - set `:size` explicitly if you want narrower derived IDs.

To turn an ID string back into its key or schema (`known?/1`, `key_for/1`,
`schema_for/1`, `resolve/1`), see
[By ID string - the runtime routing table](registry-reference.md#by-id-string-the-runtime-routing-table).

## Routing in a layered or umbrella app

The `schema:` literal above points the registry **up** at a schema module. In a
flat app that is fine. But in a layered app the registry usually wants to live at
the *base* layer - so every layer can depend down on it to mint IDs and read
`field_opts/1` - while the schemas it routes to live *above* it. Naming those
schemas from the base layer inverts the dependency direction (and trips tools
like `Boundary`).

To keep the direction correct, **omit `schema:`** and let each schema register
itself under its key with `UXID.Registered`. The reference then points *down*
(schema names a registry key), never up:

```elixir
# base layer - governance only, no schema: literal
defmodule MyApp.IDs do
  use UXID.Registry
  defid :user, prefix: "usr", route: true   # filled at boot by self-registration
end

# upper layer - the schema marks itself
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  use UXID.Registered, key: :user
  @primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:user)}
end
```

`route: true` marks a key that *must* resolve to a schema (a `schema:` literal
sets this automatically; a mid-migration entry with neither stays unrouted and is
not required).

### Building and verifying the table at boot

At boot, `verify!/1` scans the given OTP apps for the marker (by reflection - no
base-layer reference to an upper-layer module), assembles the prefix → schema
table into `:persistent_term`, and validates it. Wire it into your top app's
`start/2` so **every** boot - prod, dev, and CI's `mix test` - re-verifies:

```elixir
def start(_type, _args) do
  MyApp.IDs.verify!(otp_apps: [:my_app])   # or all umbrella apps: [:core, :accounts, :web]
  # ... start your supervision tree
end
```

`verify!/1` raises `ArgumentError`, listing every problem, when:

- a marker names a key that isn't registered (a typo like `key: :uesr`),
- two modules claim the same key, or
- a `route: true` key resolves to no schema.

After it runs, `schema_for/1` resolves layered schemas from the table (flat-app
`schema:` literals resolve with no build at all - `schema_for/1` checks the
literal first, then the table).

## Verifying uniqueness & correctness in CI

You don't need a bespoke CI job - CI already boots your app when it runs
`mix test`, and `verify!/1` in `start/2` runs on that boot. Between the compiler
and `verify!/1` you get:

| Guarantee | Where it's checked |
|---|---|
| Prefix uniqueness + format | Compile time |
| Marker typos, duplicate schema claims, routing completeness | `verify!/1` at boot (prod, dev, CI) |

The one thing the library can't know is "every schema actually draws its id from
the registry." That stays an app-side test. With `prefixes/0` and two small
reflection helpers it's a handful of lines - discover every UXID-keyed schema in
your app and assert each prefix is registered:

```elixir
defmodule MyApp.IDConformanceTest do
  use ExUnit.Case, async: true

  # Ecto stores a UXID field as a parameterized type; pull its :prefix back out.
  defp uxid_prefix(schema, field) do
    case schema.__schema__(:type, field) do
      {:parameterized, {UXID, %{prefix: prefix}}} -> prefix
      {:parameterized, UXID, %{prefix: prefix}} -> prefix
      _ -> nil
    end
  end

  # Every Ecto schema in an app whose (single) primary key is a UXID.
  defp uxid_schemas(app) do
    for mod <- Application.spec(app, :modules) || [],
        Code.ensure_loaded?(mod),
        function_exported?(mod, :__schema__, 1),
        [pk] <- [mod.__schema__(:primary_key)],
        prefix = uxid_prefix(mod, pk),
        prefix != nil,
        do: {mod, prefix}
  end

  test "every UXID-keyed schema draws its prefix from the registry" do
    for {schema, prefix} <- uxid_schemas(:my_app) do
      assert prefix in MyApp.IDs.prefixes(),
             "#{inspect(schema)} uses unregistered UXID prefix #{inspect(prefix)}"
    end
  end
end
```

## Sharing the registry across sources (JSON manifest)

UXIDs are source-agnostic - you can mint them in Postgres with `INSERT ... SELECT`
or on a mobile/JS client that generates an ID offline before upload. To keep the
Elixir registry the single source of truth in those places too, export a JSON
manifest and let the other runtime read it:

```elixir
MyApp.IDs.manifest()
# => [%{"key" => "org", "prefix" => "org", "size" => "medium",
#       "category" => "account", "deterministic" => false,
#       "monotonic" => nil, "compact_time" => nil, "rand_size" => nil}, ...]

MyApp.IDs.manifest_json()
# => ~s([{"key":"org","prefix":"org","size":"medium","category":"account","deterministic":false,"monotonic":null,"compact_time":null,"rand_size":null}, ...])
```

`manifest/0` returns plain JSON-safe data (string keys, scalar values, `nil` for
unset fields) that you can hand to any JSON library; `manifest_json/0` returns a
ready-to-write string with no extra dependency. A common pattern is a tiny Mix
task or release step that writes it to a file your database migrations or client
build consume, so every generator agrees on prefixes and sizes:

```elixir
# lib/mix/tasks/uxid.manifest.ex
defmodule Mix.Tasks.Uxid.Manifest do
  use Mix.Task
  @shortdoc "Writes the UXID prefix manifest to priv/uxid_manifest.json"
  def run(_args) do
    File.write!("priv/uxid_manifest.json", MyApp.IDs.manifest_json())
  end
end
```

The manifest carries `prefix`, `size` (which fixes the random length), `category`,
`key`, `deterministic`, and the body-shape options `monotonic`, `compact_time`,
and `rand_size` (`null` when the key defers to the app's global configuration);
combine each `prefix` with the registry's delimiter and a Base32 body to assemble
an ID anywhere. `compact_time` in particular is not optional reading for another
generator - it changes the encoded length, 8 timestamp characters rather than 10.

`deterministic` tells another generator *which scheme* a key uses, not how to
implement it - a generator that ignored the flag would mint a random ID for a
derived key, which is exactly the cross-source drift the manifest exists to
prevent. Reproducing the scheme itself (SHA-256 over prefix + input, the `z`
marker, the hash-char table) is on the implementer; see the
[Deterministic IDs guide](deterministic.md).

