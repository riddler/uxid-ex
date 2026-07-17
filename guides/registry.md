# Prefix Registry

A prefix only pays off — "the ID names its resource on sight" — when it is
globally unique and well-formed across your whole app. `UXID.Registry` is an
opt-in, compile-time DSL that makes those guarantees the compiler's job instead
of a hand-rolled CI test, and turns the same declarations into a runtime routing
table (prefix → schema) for the ID-driven patterns Adam Kirk describes in his
ElixirConf US 2025 talk, [_UXIDs in Elixir/Ecto_][uxid_talk_url]
(authorization/IDOR checks, admin auto-linking, Relay global IDs).

## Declaring a registry

Declare one registry module as your single source of truth:

```elixir
defmodule MyApp.IDs do
  use UXID.Registry,
    default_size: :medium,
    default_validate: true

  defid :org,     prefix: "org",     schema: MyApp.Org,             category: :account
  defid :contact, prefix: "contact", size: :large, schema: MyApp.CRM.Contact
  defid :lead,    prefix: "lead"
  retired "usr" # reserve a prefix so it stays unique-checked, never reused
end
```

**Compile-time guarantees.** Every prefix is checked against `:prefix_format`
(overridable; the default permits an internal underscore for compound prefixes
like `in_ref`), and all prefixes — active *and* `retired` — are checked for
uniqueness. A malformed or duplicate prefix is a compile error, so the governance
every prefixed-ID scheme needs ships in the library.

Keep to **one registry module per app**: compile-time uniqueness only holds
within a single module, since the library never sees two registries together.

## By key — minting and schema configuration

```elixir
MyApp.IDs.generate!(:org)   # => "org_01h…"
MyApp.IDs.prefix(:org)      # => "org"
MyApp.IDs.size(:org)        # => :medium
MyApp.IDs.schema(:org)      # => MyApp.Org
MyApp.IDs.all()             # => [%{key: :org, prefix: "org", schema: MyApp.Org, ...}, ...]
```

`field_opts/1` is the single-source-of-truth hook — a schema spreads it instead
of restating prefix/size/validate anywhere:

```elixir
@primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:org)}
```

## By ID string — the runtime routing table

This is the "which resource is this?" map that powers authorization scans, admin
tooling, and global-ID resolution:

```elixir
MyApp.IDs.known?("org_01h…")      # => true   (cheap prefix-only membership check)
MyApp.IDs.key_for("org_01h…")     # => :org
MyApp.IDs.schema_for("org_01h…")  # => MyApp.Org
MyApp.IDs.resolve("org_01h…")     # => %{key: :org, schema: MyApp.Org, category: :account, ...}
```

Lookups split an ID on the **last** delimiter, which is unambiguous without any
registry lookup because a UXID body is Crockford Base32 and never contains the
delimiter — so `in_ref_01h…` recovers the `in_ref` prefix cleanly. For that
reason the `:delimiter` must be a character that cannot appear in a Base32 body
(`"_"` — the default — or `"-"`); an underscore is preferred for compound
prefixes since it does not break double-click-to-select-the-whole-id.

## Routing in a layered or umbrella app

The `schema:` literal above points the registry **up** at a schema module. In a
flat app that is fine. But in a layered app the registry usually wants to live at
the *base* layer — so every layer can depend down on it to mint IDs and read
`field_opts/1` — while the schemas it routes to live *above* it. Naming those
schemas from the base layer inverts the dependency direction (and trips tools
like `Boundary`).

To keep the direction correct, **omit `schema:`** and let each schema register
itself under its key with `UXID.Registered`. The reference then points *down*
(schema names a registry key), never up:

```elixir
# base layer — governance only, no schema: literal
defmodule MyApp.IDs do
  use UXID.Registry
  defid :contact, prefix: "contact", route: true   # filled at boot by self-registration
end

# upper layer — the schema marks itself
defmodule MyApp.CRM.Contact do
  use Ecto.Schema
  use UXID.Registered, key: :contact
  @primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:contact)}
end
```

`route: true` marks a key that *must* resolve to a schema (a `schema:` literal
sets this automatically; a mid-migration entry with neither stays unrouted and is
not required).

### Building and verifying the table at boot

At boot, `verify!/1` scans the given OTP apps for the marker (by reflection — no
base-layer reference to an upper-layer module), assembles the prefix → schema
table into `:persistent_term`, and validates it. Wire it into your top app's
`start/2` so **every** boot — prod, dev, and CI's `mix test` — re-verifies:

```elixir
def start(_type, _args) do
  MyApp.IDs.verify!(otp_apps: [:my_app])   # or all umbrella apps: [:core, :crm, :web]
  # ... start your supervision tree
end
```

`verify!/1` raises `ArgumentError`, listing every problem, when:

- a marker names a key that isn't registered (a typo like `key: :contct`),
- two modules claim the same key, or
- a `route: true` key resolves to no schema.

After it runs, `schema_for/1` resolves layered schemas from the table (flat-app
`schema:` literals resolve with no build at all — `schema_for/1` checks the
literal first, then the table).

## Verifying uniqueness & correctness in CI

You don't need a bespoke CI job — CI already boots your app when it runs
`mix test`, and `verify!/1` in `start/2` runs on that boot. Between the compiler
and `verify!/1` you get:

| Guarantee | Where it's checked |
|---|---|
| Prefix uniqueness + format | Compile time |
| Marker typos, duplicate schema claims, routing completeness | `verify!/1` at boot (prod, dev, CI) |

The one thing the library can't know is "every schema actually draws its id from
the registry." That stays an app-side test. With `prefixes/0` and two small
reflection helpers it's a handful of lines — discover every UXID-keyed schema in
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

UXIDs are source-agnostic — you can mint them in Postgres with `INSERT ... SELECT`
or on a mobile/JS client that generates an ID offline before upload. To keep the
Elixir registry the single source of truth in those places too, export a JSON
manifest and let the other runtime read it:

```elixir
MyApp.IDs.manifest()
# => [%{"key" => "org", "prefix" => "org", "size" => "medium", "category" => "account"}, ...]

MyApp.IDs.manifest_json()
# => ~s([{"key":"org","prefix":"org","size":"medium","category":"account"}, ...])
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
and `key`; combine each `prefix` with the registry's delimiter and a Base32 body
to assemble an ID anywhere.

<!-- LINKS -->
[uxid_talk_url]: https://www.youtube.com/watch?v=YIIJClhjxOA
