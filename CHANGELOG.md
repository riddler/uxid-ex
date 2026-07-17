# Changelog

## Upcoming

* Adds runtime prefix → schema routing for **layered apps**, so a `UXID.Registry` can live at an app's base layer without a `schema:` literal inverting the dependency direction:
  - New `UXID.Registered` mixin (`use UXID.Registered, key: :contact`) marks a schema under a registry key; the reference points *down* (schema names a key), so the base-layer registry never references an upper-layer module — `Boundary`/`xref` stay clean
  - `MyApp.IDs.verify!(otp_apps: [...])` / `build_routes!/1` assemble the routing table at boot by scanning the given apps for the marker (via reflection, no compile-visible module reference) and store it in `:persistent_term`; `verify!/1` also validates it — raising on a marker that names an unregistered key, two modules claiming one key, or a `route: true` key left unmapped
  - Call `verify!/1` from your top app's `start/2` so every boot (prod, dev, CI's `mix test`) re-verifies — no bespoke CI job needed
  - `schema_for/1` now resolves a compile-time `schema:` literal first, then the self-registration table, so flat apps are unchanged and layered apps opt in per entry with `route: true`
  - Adds `prefixes/0` (convenience for app-side "every schema draws from the registry" conformance tests) and `routes/0`
* Restructures the documentation: a slimmed README plus dedicated guides (Sizes & Encoding, Ecto Integration, Monotonic IDs, Prefix Registry, Configuration) that render on both GitHub and HexDocs

## 2.5.0 / 2026-07-16

* Adds `UXID.Registry`, an opt-in compile-time DSL for an app's prefixes via `use UXID.Registry` with `defid`/`retired`:
  - Compile-time uniqueness (active and `retired` prefixes) and prefix-format checks, replacing per-app CI tests
  - By-key API: `generate!/1`, `generate/1`, `prefix/1`, `size/1`, `schema/1`, `category/1`, `field_opts/1`, `all/0`, `keys/0`, `reserved/0`
  - By-ID-string routing (prefix → schema): `known?/1`, `key_for/1`, `schema_for/1`, `resolve/1`; parsing splits on the last delimiter (unambiguous because a Base32 body never contains it), and the configurable delimiter is validated as Base32-disjoint (defaults to `_`)
  - JSON manifest export (`manifest/0`, `manifest_json/0`) so database functions and mobile/JS clients mint prefixes from the same source of truth, with no added dependency
  - Registers `defid`/`retired` as paren-free locals and exports the rule for consuming apps
* Adds opt-in monotonic generation via the `monotonic` option (per-call/per-field) or `config :uxid, :monotonic` global policy:
  - Accepts `true`/`false`, or a list of sizes (alias-aware, e.g. `[:small]` matches both `:small` and `:s`)
  - Within a millisecond the random field is seeded once then advanced by a random positive step (uniform over `[1, 2^(bits/2)]`, drawn from the CSPRNG), guaranteeing uniqueness and K-sortability for a burst — process-local, `async: true` safe, no GenServer/ETS
  - Per-call option takes precedence over the global policy; off by default (consecutive IDs stay in a bounded window — a mitigation, not cryptographic unpredictability — weakening enumeration resistance)
  - `:xs`/`:xsmall` auto-enable `compact_time` so there is a field to increment; explicit `compact_time: false` on those sizes with monotonic on raises
  - Wire format is byte-identical to a random UXID — no decoder changes

## 2.4.0 / 2026-07-09

* Adds `UXID.valid?/2` for structural validation of a UXID string (optional `:prefix` and `:delimiter`)
* Adds opt-in strict casting for the Ecto type via `validate: true` on a field:
  - Accepts a well-formed UXID carrying the field's configured `:prefix`, or a legacy bare UUID string
  - Rejects malformed values (empty, wrong prefix, non–Base32) with `:error`
  - UUID coexistence is on by default (eases `uuid` → `text` column migrations); disable with `allow_uuid: false`
  - Default casting is unchanged (any binary passes) when `validate` is not set — fully backwards compatible
* Adds default_delimiter config accessor

## 2.3.0 / 2026-01-16

* Adds min_size config option to enforce minimum UXID sizes (useful for test environments)
* Adds compact_time feature for improved collision resistance in small UXIDs:
  - Global policy via `compact_small_times` config automatically compacts :xs/:xsmall/:s/:small sizes
  - Per-call override via `compact_time: true/false` option works for any size
  - Uses 40-bit timestamps (8 chars) instead of 48-bit (10 chars), freeing 8 bits for randomness
  - Example: :small gains 50% more randomness (24 bits vs 16 bits)
  - Decoder automatically detects compact format from length and reconstructs full timestamp
  - K-sortability maintained until ~September 2039

## 2.2.0 / 2025-09-12

* Adds UXID.Decoder module with full pipeline processing and uppercase/lowercase support

## 2.1.0 / 2025-09-10

* Adds delimiter option (default is '_')
* Adds UXID.Codec with encoding struct and type
* Fixes Dialyzer issues
* Changes UXID type to String.t() to work better with TypedEctoSchema
* Changes how Ecto.Paramaterized type is implemented to work in projects without Ecto

## 2.0.0 / 2025-04-27

### Breaking Changes

* Adds case config and functionality
* Makes lowercase the default
* Removes deprecated Ecto.UXID

## 1.0.0 / 2025-04-13

* Fixes compiler warnings

## 0.2.3 / 2020-11-29

* Uses new project URL

## 0.2.2 / 2020-11-26

* Passes options cleanly down for autogenerate

## 0.2.1 / 2020-11-24

* Updates Mix project description

## 0.2.0 / 2020-11-22

* Deprecates Ecto.UXID
* Removes Decoder and CrockfordBase32
* Adds size option (T-Shirt sizes)

## 0.1.2 / 2020-11-07

* Updates description and README

## 0.1.1 / 2020-11-07

* Updates description and README

## 0.1.0 / 2020-11-06

* Updates description and README
* Has enough usable functionality and documentation for 0.1.0!

## 0.0.6 / 2020-10-30

* Marks Ecto as optional dependency and excludes xref

## 0.0.5 / 2020-10-19

* Adds Ecto.UXID

## 0.0.4 / 2020-10-19

* Includes Erlang crypto application

## 0.0.3 / 2020-10-12

* Fixes documentation

## 0.0.2 / 2020-10-11

* Adds generation of UXIDs

## 0.0.1 / 2020-06-17

* Birthday!
