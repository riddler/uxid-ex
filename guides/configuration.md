# Configuration

Every option below can be set globally under `config :uxid, ...` and, except
where noted, overridden per call or per Ecto field. Per-call options always win
over global config.

| Key                   | Default   | Purpose |
|-----------------------|-----------|---------|
| `:case`               | `:lower`  | Default case of generated IDs (`:lower` or `:upper`). |
| `:delimiter`          | `"_"`     | Character joining prefix and body. Must not appear in a Base32 body (`"_"` or `"-"`). |
| `:min_size`           | `nil`     | Floor that upgrades any smaller requested size. Off when `nil`. |
| `:compact_small_times`| `false`   | Auto-enable compact time for `:xs`/`:xsmall`/`:s`/`:small`. |
| `:monotonic`          | `false`   | Global monotonic policy: `true`, `false`, or a list of sizes. |

## `:case`

Controls the default case for generated UXIDs. Lowercase by default; uppercase
matches earlier UXID versions.

```elixir
# config/config.exs
config :uxid, case: :upper

UXID.generate!()               # => "01EMDGJF0DQXQJ8FM78XE97Y3H"
UXID.generate!(case: :lower)   # => "01emdgjf0dqxqj8fm78xe97y3h"  (per-call override)
```

## `:delimiter`

The character placed between the prefix and the body. It must be a character that
cannot appear in a Crockford Base32 body — `"_"` (the default) or `"-"` — so that
prefix parsing stays unambiguous. An underscore keeps double-click-to-select
working. Override per call with `delimiter:`; a `UXID.Registry` sets it per
registry with `delimiter:`.

## `:min_size`

Enforces a minimum size regardless of what is requested. Useful in test
environments where rapid ID generation can cause duplicate-key violations at
small sizes. Any requested size below the floor is upgraded; larger sizes are
untouched.

```elixir
# config/test.exs
config :uxid, min_size: :medium

UXID.generate!(prefix: "usr", size: :small)   # => an 18-char (:medium) body in test
```

## `:compact_small_times`

Global policy that enables [compact time](sizes.md#compact-time) for the small
sizes (`:xs`/`:xsmall`/`:s`/`:small`), trading 8 bits of timestamp for 8 bits of
randomness. Override per call or per field with `compact_time: true | false`.

```elixir
# config/test.exs
config :uxid, compact_small_times: true

UXID.generate!(size: :small)                    # compact (13-char body)
UXID.generate!(size: :small, compact_time: false) # opt back out for this call
UXID.generate!(size: :large, compact_time: true)  # opt in for a size the policy skips
```

## `:monotonic`

Global monotonic policy. Accepts `true` (all sizes), `false`, or a list of sizes
(alias-aware — `[:small]` matches both `:small` and `:s`). Override per call or
per field with `monotonic:`. See the [Monotonic IDs guide](monotonic.md) for the
guarantee and its security tradeoff.

```elixir
# config/config.exs
config :uxid, monotonic: [:small, :medium]

UXID.generate!(size: :small)                  # monotonic (matches policy)
UXID.generate!(size: :small, monotonic: false) # opt out for this call
```
