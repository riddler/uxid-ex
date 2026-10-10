# Why monotonic mode exists and what it costs

Standard UXIDs draw fresh randomness for every ID, so collision risk within a
single millisecond is a birthday problem - for small sizes (`:xsmall` has 0
random bits, `:small` has 16) a burst of same-millisecond IDs can collide.
Monotonic mode fixes this the way the ULID monotonic spec does: within a
millisecond it seeds the random field once from the CSPRNG, then advances it by a
**random positive step** for each subsequent ID. That turns "birthday collision
among N draws" into "guaranteed distinct until the field overflows," and because
the field is encoded big-endian, a strictly increasing counter also sorts
strictly after - K-sortability is preserved at every size.

The step is uniform over `[1, 2^(bits/2)]` (the square root of the field space,
auto-derived from the size - no configuration). Stepping by a random amount
instead of exactly `+1` means an attacker who sees `...0004` can no longer guess
`...0005`: single-shot guess cost rises from certainty to `~1/2^(bits/2)` (1/256 at
`:small`, ~1/10⁶ at `:medium`), while still leaving ample same-ms burst headroom
before overflow (~512 IDs/ms at `:small`, ~2M at `:medium`).

To turn it on per call, per Ecto field, per registry key or globally, see
[Turn on monotonic generation](tuning.md#turn-on-monotonic-generation).

## Why the small sizes need it most

The birthday arithmetic in [Collision resistance](sizes.md#collision-resistance)
bites hardest at the small sizes. A `:small` body has 16 random bits, so about
36 IDs minted in one millisecond already reach a 1% chance of a collision.
Under monotonic mode, same-millisecond IDs from one process are **guaranteed
distinct** (and strictly ordered) rather than merely unlikely to collide, so
that budget of about 36 becomes the field's whole range before overflow. That
is why monotonic mode is the answer when you need a small ID *and* a high
same-millisecond burst rate, and why it is not free: the next section is what
it costs.

The guarantee holds within one BEAM process; its exact scope is stated under
[`:monotonic`](configuration.md#monotonic) in the Configuration reference.

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

`:xs` has no random field to step, so monotonic mode treats it specially; see
[`:xs` under monotonic generation](sizes.md#xs-under-monotonic-generation).
