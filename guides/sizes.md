# Sizes & Encoding

A UXID body is a [Crockford Base32][crockford_url] string made of two parts: a
timestamp (which makes IDs K-sortable) followed by random bytes. The `:size`
option controls how many random bytes are used, so you can spend fewer
characters on low-cardinality resources and more where collision resistance
matters.

## T-shirt sizes

Pass `:size` as a t-shirt size - either the short or long alias:

| Size          | Aliases      | Random bits | Body length |
|---------------|--------------|-------------|-------------|
| `:xs`         | `:xsmall`    | 0           | 10 chars    |
| `:s`          | `:small`     | 16          | 14 chars    |
| `:m`          | `:medium`    | 40          | 18 chars    |
| `:l`          | `:large`     | 56          | 22 chars    |
| `:xl`         | `:xlarge`    | 80          | 26 chars    |

Body length excludes the prefix and delimiter - `cus_` adds four more characters.
With no `:size`, generation defaults to 80 random bits (the same as `:xl`).

```elixir
UXID.generate!(prefix: "cus", size: :small)   # "cus_01eqrh884aqyy1"  (14-char body)
UXID.generate!(prefix: "cus", size: :xl)      # "cus_01kxr2jnqndq7qx9wrvhmrzrhw"
```

[Deterministic IDs](deterministic.md) reuse these same body lengths, but spend
the whole body (minus the one-character `z`/`Z` marker) on hash bits instead of a
timestamp plus randomness - so a deterministic `:m` body is 85 hash bits, not 40.

### `:xs` under monotonic generation

A standard `:xs` has 0 random bits - nothing to increment - so when
[monotonic generation](monotonic.md) is active `compact_time` is enabled
automatically for `:xs`/`:xsmall`, yielding a 1-byte (8-bit) counter field.
Passing an explicit `compact_time: false` on `:xs`/`:xsmall` with monotonic on
raises an `ArgumentError` (there would be no field to count). This inherits the
compact `:xsmall` time-decode ambiguity described under
[Compact time](#compact-time) - uniqueness and sorting are unaffected, but
decoding the timestamp back out of a monotonic `:xs` is unreliable.

## Collision resistance

Two UXIDs can only collide if they share the **same millisecond timestamp** *and*
the same random field. IDs generated in different milliseconds never collide, so
collision risk is a [birthday problem][birthday_url] over the `2^(random bits)`
values available **within a single millisecond**. The more IDs you mint in one
millisecond (a bulk insert, a seed script, a burst of events), the higher the
chance two draw the same random field.

As a rule of thumb, the 50% collision point is around the square root of the
space (`2^(bits/2)`). The table below shows how many same-millisecond IDs you can
mint before the odds cross ~1%:

| Size       | Random bits | Distinct random values | Same-ms IDs for ~1% collision |
|------------|-------------|------------------------|-------------------------------|
| `:xs`      | 0           | 1                      | the 2nd same-ms ID collides   |
| `:s`       | 16          | 65,536                 | ~36                           |
| `:m`       | 40          | ~1.1 × 10¹²            | ~150,000                      |
| `:l`       | 56          | ~7.2 × 10¹⁶            | ~38 million                   |
| `:xl`      | 80          | ~1.2 × 10²⁴            | ~150 billion                  |

The numbers are per millisecond and per independent generator - spread the same
burst across processes or nodes and the same-millisecond draws still share the
space, so the birthday math spans all of them together.

> #### Choosing a size {: .tip}
>
> Pick a size from the *peak same-millisecond burst rate*, not the total row
> count. A table with billions of rows minted a few per millisecond is fine at
> `:small`; a bulk import that inserts 100k rows in one transaction is not.
> `:xs` carries **no** randomness (timestamp only), so it is only safe for
> genuinely singleton or externally-keyed resources.

To make a small size burst-safe within one process, see
[Why the small sizes need it most](monotonic.md#why-the-small-sizes-need-it-most).

## Compact time

Standard UXIDs use a 48-bit timestamp (10 characters). Compact-time mode drops
that to a 40-bit timestamp (8 characters) and hands the freed 8 bits to the
random field - more collision resistance, often in *fewer* characters:

```elixir
UXID.generate!(size: :small)                     # 14-char body, 16 random bits
UXID.generate!(size: :small, compact_time: true) # 13-char body, 24 random bits
```

- Reduces the timestamp from 48 bits (10 chars) to 40 bits (8 chars).
- Frees 8 bits for randomness - e.g. `:small` gains 50% more (24 vs 16 bits).
- Keeps perfect 5-bit Crockford Base32 alignment.
- Stays K-sortable until ~mid-2038, after which the compact encoder raises: value 31 (the first char `z`/`Z`) is reserved as the [deterministic-ID](deterministic.md) scheme marker, so no compact timestamp may emit it. Standard 48-bit timestamps are unaffected.
- The decoder auto-detects the compact format from the length and reconstructs the full timestamp.

Compact time is useful for test suites that mint IDs rapidly and for small
resources that need better collision resistance without growing longer. Enable it
per call (`compact_time: true`), per Ecto field, or globally for small sizes -
see the [Configuration guide](configuration.md).

To raise every small size to a floor in a test suite, see
[Enforce a minimum size in tests](tuning.md#enforce-a-minimum-size-in-tests).

<!-- LINKS -->
[crockford_url]: https://www.crockford.com/base32.html
[birthday_url]: https://en.wikipedia.org/wiki/Birthday_problem
