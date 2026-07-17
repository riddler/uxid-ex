# UXID

[![MIT License][badge_license_url]](LICENSE)
[![Hex Version][badge_version_url]](https://hex.pm/packages/uxid)
[![Hex Downloads][badge_downloads_url]](https://hex.pm/packages/uxid)

**U**ser e**X**perience focused **ID**entifiers (UXIDs) are prefixed, K-sortable,
Stripe-style identifiers like `usr_01epey2p06tr1rtv07xa82zgjj`. They are:

* Descriptive — the prefix names the resource on sight (aids debugging and investigation)
* Copy/paste friendly — double-clicking selects the entire ID
* Tunable in size — shortened for low-cardinality resources
* Secure against enumeration attacks
* Application-generated — not tied to the datastore
* K-sortable — lexicographically sortable by time, so they index well
* Coordination-free — no startup or generation-time coordination required
* Unlikely to collide — more randomness, lower odds
* Human-transmissible — easy to read out accurately over the phone
* Optionally **monotonic** — a burst within one millisecond stays unique and strictly ordered
* Optionally **governed by a registry** — one module keeps every prefix unique and maps an ID back to its resource

Many of the concepts of [Stripe IDs][stripe_ids_url] have been used in this library.

## Installation

Add `uxid` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:uxid, "~> 2.5"}
  ]
end
```

Ecto is an optional dependency — UXID only pulls it in if your app already uses it.

## Quick start

```elixir
# No options generates a plain ULID
UXID.generate!()                              # "01emdgjf0dqxqj8fm78xe97y3h"

# Add a prefix to name the resource
UXID.generate!(prefix: "cus")                 # "cus_01emdgjf0dqxqj8fm78xe97y3h"

# Shrink the random part for low-cardinality resources
# T-shirt sizes: :xs :s :m :l :xl (or :xsmall :small :medium :large :xlarge)
UXID.generate!(prefix: "cus", size: :small)   # "cus_01eqrh884aqyy1"

# Uppercase to match earlier UXID versions
UXID.generate!(case: :upper)                  # "01EMDGJF0DQXQJ8FM78XE97Y3H"
```

## Ecto in 30 seconds

UXIDs work as Ecto fields, including primary keys — set the field type to `UXID`
and pass the same options you'd pass to `generate!/1`:

```elixir
defmodule YourApp.User do
  use Ecto.Schema

  @primary_key {:id, UXID, autogenerate: true, prefix: "usr", size: :medium}
  schema "users" do
    field :api_key, UXID, autogenerate: true, prefix: "apikey", size: :small
  end
end
```

See the [Ecto Integration guide](guides/ecto.md) for foreign keys, strict
validation, and migrating a `uuid` column to UXIDs.

## Guides

The five-minute path is above; each area has a dedicated guide:

* **[Sizes & Encoding](guides/sizes.md)** — the t-shirt sizes, how much randomness each carries, and compact-time mode for extra collision resistance.
* **[Ecto Integration](guides/ecto.md)** — primary/foreign keys, strict `validate:` casting, `allow_uuid` coexistence, and `UXID.valid?/2`.
* **[Monotonic IDs](guides/monotonic.md)** — guaranteed same-millisecond uniqueness and ordering, the security tradeoff, and when to use it.
* **[Prefix Registry](guides/registry.md)** — a compile-time DSL that keeps every prefix unique, routes an ID back to its schema, works in layered/umbrella apps, and exports a cross-source JSON manifest.
* **[Configuration](guides/configuration.md)** — every `config :uxid` key in one place, with per-call vs. global precedence.

## Documentation

Full API docs are on [HexDocs][hexdocs_project_url]. The registry and routing
patterns are drawn from Adam Kirk's ElixirConf US 2025 talk,
[_UXIDs in Elixir/Ecto_][uxid_talk_url].

## License

UXID is released under the [MIT License](LICENSE).

<!-- LINKS -->
[hex_project_url]: https://hex.pm/packages/uxid
[hexdocs_project_url]: https://hexdocs.pm/uxid
[mit_license_url]: http://opensource.org/licenses/MIT
[uxid_talk_url]: https://www.youtube.com/watch?v=YIIJClhjxOA
[stripe_ids_url]: https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a

<!-- BADGES -->
[badge_license_url]: https://img.shields.io/badge/license-MIT-brightgreen.svg?cacheSeconds=3600?style=flat-square
[badge_downloads_url]: https://img.shields.io/hexpm/dt/uxid?style=flat&logo=elixir
[badge_version_url]: https://img.shields.io/hexpm/v/uxid?style=flat&logo=elixir
