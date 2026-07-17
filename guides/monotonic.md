# Monotonic IDs

Standard UXIDs draw fresh randomness for every ID, so collision risk within a
single millisecond is a birthday problem — for small sizes (`:xsmall` has 0
random bits, `:small` has 16) a burst of same-millisecond IDs can collide.
Monotonic mode fixes this the way the ULID monotonic spec does: within a
millisecond it seeds the random field once from the CSPRNG, then advances it by a
**random positive step** for each subsequent ID. That turns "birthday collision
among N draws" into "guaranteed distinct until the field overflows," and because
the field is encoded big-endian, a strictly increasing counter also sorts
strictly after — K-sortability is preserved at every size.

The step is uniform over `[1, 2^(bits/2)]` (the square root of the field space,
auto-derived from the size — no configuration). Stepping by a random amount
instead of exactly `+1` means an attacker who sees `…0004` can no longer guess
`…0005`: single-shot guess cost rises from certainty to `~1/2^(bits/2)` (1/256 at
`:small`, ~1/10⁶ at `:medium`), while still leaving ample same-ms burst headroom
before overflow (~512 IDs/ms at `:small`, ~2M at `:medium`).

## Enabling it

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

## Scope of the guarantee

Monotonic and collision-free *within a single BEAM process*. State lives in the
process dictionary (keyed by prefix and field size) — no GenServer, no ETS, no
shared state, so it is `async: true` safe. Each process gets an independent
random starting point per millisecond, so cross-process collisions fall back to a
birthday probability on the field size.

## Tradeoff (why it is opt-in)

The random step is a *mitigation, not cryptographic unpredictability*. It removes
trivial `+1` enumeration, but an attacker who observes two consecutive same-ms
IDs learns the actual gap, and values still lie in a bounded window ahead.
Low-entropy sizes stay low-entropy, so monotonic must be a conscious per-resource
choice and is never a silent default.

> #### Don't use small monotonic IDs as public, enumerable identifiers {: .warning}
>
> Don't use `:small`/`:medium` monotonic IDs as externally-enumerable,
> security-sensitive identifiers; prefer `:large`/`:xl` (and non-monotonic) there.

## `:xs` / `:xsmall` note

A standard `:xs` has 0 random bits — nothing to increment — so when monotonic is
active `compact_time` is enabled automatically for `:xs`/`:xsmall`, yielding a
1-byte (8-bit) counter field. Passing an explicit `compact_time: false` on
`:xs`/`:xsmall` with monotonic on raises an `ArgumentError` (there would be no
field to count). This inherits the compact `:xsmall` time-decode ambiguity
described in the [Sizes & Encoding guide](sizes.md#compact-time) — uniqueness and
sorting are unaffected, but decoding the timestamp back out of a monotonic `:xs`
is unreliable.
