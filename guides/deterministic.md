# Deterministic IDs

Standard UXIDs are random: calling `generate!/1` twice with the same options
gives two different IDs. Deterministic mode is the opposite - **the same input
string always maps to the same ID**, forever, across processes and machines.
This is what a name-based UUID (UUIDv5) gives you, adapted to the UXID format.

Reach for it when you want a stable ID derived from an external key without a
lookup table: an email, a vendor SKU, a webhook idempotency key, or a natural key
during a migration. It makes idempotent upserts trivial (recompute the ID instead
of querying for it) and gives you stable fixtures and seeds in tests.

You switch it on by passing `from:` with the input string; the option is in
[The `from:` option](deterministic-reference.md#the-from-option). A registry
key can require it: see [Deterministic keys](registry.md#deterministic-keys)
in the registry guide.

## Prefix is the namespace

The prefix is folded into the hash as the namespace, so the same string under two
prefixes produces two unrelated bodies - `usr` + `"alice@example.com"` and `org`
+ `"alice@example.com"` never collide:

```elixir
UXID.generate!(prefix: "usr", from: "alice@example.com")  # "usr_zcvt7epac..."
UXID.generate!(prefix: "org", from: "alice@example.com")  # "org_zes4c99fn..."  (unrelated)
```

Most callers pass just `prefix` + `from` and get correct scoping with zero extra
config. (There is no separate `namespace:` option; the prefix does that job. No
prefix at all hashes into the global scope.)

## The `z` marker and sort order

A deterministic body always starts with `z` (or `Z` in upper case) - Crockford
value 31, the maximum symbol. It does two jobs:

1. **Self-identifying** - a human or the decoder can see at a glance that the ID
   is hash-derived, not time-derived. `UXID.deterministic?/1` reports it, and
   `decode/1` returns `deterministic: true` with `time: nil`.
2. **Sorts last** - because `z` is the highest value, every deterministic ID
   sorts *after* every time-based ID. They cluster at the end of an index instead
   of interleaving with (and polluting) the K-sortable time range. Among
   themselves they sort in no meaningful order.

To keep `z` an unambiguous marker, compact-time encoding reserves value 31: a
compact timestamp can no longer start with `z`, which trims the compact horizon
to ~mid-2038 (standard 48-bit timestamps are unaffected). See the
[Sizes & Encoding guide](sizes.md#compact-time).

The body length and hash width at each size are in
[Size and length](deterministic-reference.md#size-and-length).

## Properties, honestly

- **Deterministic & idempotent** - same `{namespace, name, size, case}` → same ID,
  everywhere, forever.
- **Not time-ordered** - hash order is effectively random-but-stable. These sort
  after time IDs and among themselves in no meaningful order, so do not rely on
  them for K-sortability.
- **Not a secret** - a deterministic ID is a hash of a *known* input, so it is
  exactly as guessable as that input. Anyone who knows the namespace + name can
  recompute the ID. Do **not** derive an ID from a low-entropy secret and treat
  the ID as unguessable. (This is the same caveat RFC 4122 gives for name-based
  UUIDs.)

> #### Deterministic IDs are not unguessable {: .warning}
>
> If you need an identifier an attacker cannot guess, use a random UXID (`:large`
> or `:xl`), not a deterministic one. `from:` is for stability, not secrecy.

Minting one into an Ecto field, which `autogenerate` cannot do, is in
[Minting a deterministic ID in a changeset](ecto.md#minting-a-deterministic-id-in-a-changeset).
