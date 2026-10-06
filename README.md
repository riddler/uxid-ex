<img src="assets/uxid-wordmark.svg" alt="UXID" width="300">

# UXID

[![MIT License][badge_license_url]](LICENSE)
[![CI][badge_ci_url]](https://github.com/riddler/uxid-ex/actions/workflows/ci.yml)
[![Hex Version][badge_version_url]](https://hex.pm/packages/uxid)
[![Hex Downloads][badge_downloads_url]](https://hex.pm/packages/uxid)
[![Hex Docs][badge_docs_url]](https://hexdocs.pm/uxid/)

User eXperience focused IDentifiers for Elixir: prefixed, K-sortable,
Stripe-style IDs a person can read, copy and route back to their resource, with
optional Ecto types and a prefix registry. An ID looks like
`usr_01epey2p06tr1rtv07xa82zgjj`: the prefix names the resource, and the body
carries a timestamp and randomness in lowercase Crockford Base32.

## Why UXID

An auto-increment key leaks how many rows a table holds and invites
enumeration; a random UUID fixes both but is long, unordered and anonymous, so
in a log line, a URL or a support thread nobody can tell what it points at, and
a double-click selects only part of it. A UXID names its resource in its prefix,
selects whole on a double-click, reads aloud without ambiguity, sorts by
creation time so it indexes well, and is generated in the application with no
coordination between nodes. Its size is tunable for low-cardinality resources,
a monotonic mode keeps a burst within one millisecond unique and ordered, a
deterministic mode maps the same input to the same ID, and a registry keeps
every prefix in an app unique and routes an ID back to its resource.
[Why a UXID has a prefix, a time and randomness][guide_why_url] explains the
trade-offs behind these properties.

## Install

Add `uxid` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:uxid, "~> 2.9"}
  ]
end
```

Ecto is an optional dependency: UXID only uses it if your app already does.

## Basic usage

```elixir
# No options generates a plain ULID
UXID.generate!()                              # "01emdgjf0dqxqj8fm78xe97y3h"

# Add a prefix to name the resource
UXID.generate!(prefix: "cus")                 # "cus_01emdgjf0dqxqj8fm78xe97y3h"

# Shrink the random part for low-cardinality resources
# T-shirt sizes: :xs :s :m :l :xl (or :xsmall :small :medium :large :xlarge)
UXID.generate!(prefix: "cus", size: :small)   # "cus_01eqrh884aqyy1"

# Deterministic: same input -> same id, forever (prefix is the namespace)
UXID.generate!(prefix: "usr", from: "alice@example.com")
# => "usr_zcvt7epac0t1ebcsjfyf7cwz25"

# As an Ecto field type, primary keys included, with the same options
defmodule YourApp.User do
  use Ecto.Schema

  @primary_key {:id, UXID, autogenerate: true, prefix: "usr", size: :medium}
  schema "users" do
    field :api_key, UXID, autogenerate: true, prefix: "apikey", size: :small
  end
end
```

## Documentation

- Do
  - [How to use UXIDs in Ecto schemas][guide_ecto_url]: primary and foreign keys, strict `validate:` casting, `allow_uuid` coexistence, `UXID.valid?/2`, and migrating a `uuid` column.
  - [How to govern prefixes with a registry][guide_registry_url]: the compile-time DSL that keeps every prefix unique, routes an ID back to its schema, works in layered and umbrella apps, and exports a JSON manifest.
- Look up
  - [The API reference][hexdocs_api_url]: every public module and function.
  - [Sizes & Encoding][guide_sizes_url]: the t-shirt sizes, how much randomness each carries, and compact-time mode.
  - [Configuration][guide_configuration_url]: every `config :uxid` key in one place, with per-call and global precedence.
  - [The changelog][hexdocs_changelog_url]: what changed in each version.
- Understand
  - [Why a UXID has a prefix, a time and randomness][guide_why_url]: what each part of an ID is for, and what you trade when you tune it.
  - [Monotonic IDs][guide_monotonic_url]: same-millisecond uniqueness and ordering, the security tradeoff, and when to use it.
  - [Deterministic IDs][guide_deterministic_url]: name-based (UUIDv5-style) IDs, with the prefix as the namespace.
  - [_Designing APIs for humans: object IDs_][stripe_ids_url]: the Stripe ID design many of UXID's choices follow.
  - [_UXIDs in Elixir/Ecto_][uxid_talk_url]: Adam Kirk's ElixirConf US 2025 talk, the source of the registry and routing patterns.

## Compatibility

`mix.exs` declares `elixir: "~> 1.8"`. CI runs the full quality gate on the
toolchain `mise.toml` pins and the test suite alone on Elixir 1.16 / OTP 25,
the oldest pair it is tested on. There is no required runtime dependency. Ecto
is optional (`{:ecto, "~> 3.12"}`): when it is loaded, `UXID` is also an
`Ecto.ParameterizedType`; without it, everything but the Ecto type works the
same.

## License

UXID is released under the [MIT License](LICENSE).

<!-- LINKS -->
[hex_project_url]: https://hex.pm/packages/uxid
[hexdocs_api_url]: https://hexdocs.pm/uxid/api-reference.html
[hexdocs_changelog_url]: https://hexdocs.pm/uxid/changelog.html

<!-- Guide links are absolute HexDocs URLs on purpose. A relative link like
     `guides/registry.md` renders correctly on GitHub and is rewritten to
     `registry.html` by ExDoc, but hex.pm rewrites it to the raw-file preview
     (repo.hex.pm/preview/.../registry.md), which serves plain-text Markdown. -->
[guide_sizes_url]: https://hexdocs.pm/uxid/sizes.html
[guide_ecto_url]: https://hexdocs.pm/uxid/ecto.html
[guide_monotonic_url]: https://hexdocs.pm/uxid/monotonic.html
[guide_deterministic_url]: https://hexdocs.pm/uxid/deterministic.html
[guide_registry_url]: https://hexdocs.pm/uxid/registry.html
[guide_configuration_url]: https://hexdocs.pm/uxid/configuration.html
[guide_why_url]: https://hexdocs.pm/uxid/why-prefix-time-randomness.html
[mit_license_url]: http://opensource.org/licenses/MIT
[uxid_talk_url]: https://www.youtube.com/watch?v=YIIJClhjxOA
[stripe_ids_url]: https://dev.to/stripe/designing-apis-for-humans-object-ids-3o5a

<!-- BADGES -->
[badge_license_url]: https://img.shields.io/badge/license-MIT-brightgreen.svg?cacheSeconds=3600?style=flat-square
[badge_ci_url]: https://github.com/riddler/uxid-ex/actions/workflows/ci.yml/badge.svg
[badge_downloads_url]: https://img.shields.io/hexpm/dt/uxid?style=flat&logo=elixir
[badge_version_url]: https://img.shields.io/hexpm/v/uxid?style=flat&logo=elixir
[badge_docs_url]: https://img.shields.io/badge/hex-docs-lightgreen.svg
