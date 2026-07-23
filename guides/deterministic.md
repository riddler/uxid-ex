# Deterministic IDs

Standard UXIDs are random: calling `generate!/1` twice with the same options
gives two different IDs. Deterministic mode is the opposite — **the same input
string always maps to the same ID**, forever, across processes and machines.
This is what a name-based UUID (UUIDv5) gives you, adapted to the UXID format.

Reach for it when you want a stable ID derived from an external key without a
lookup table: an email, a vendor SKU, a webhook idempotency key, or a natural key
during a migration. It makes idempotent upserts trivial (recompute the ID instead
of querying for it) and gives you stable fixtures and seeds in tests.

## The `from:` API

Passing `from:` switches `generate/1`, `generate!/1`, and `new/1` into
deterministic mode. Every other option (`prefix:`, `size:`, `case:`,
`delimiter:`) works unchanged:

```elixir
UXID.generate!(prefix: "usr", from: "alice@example.com")
# => "usr_zcvt7epac0t1ebcsjfyf7cwz25"  (stable for this input, forever)

UXID.generate!(prefix: "usr", from: "alice@example.com")  # identical again
```

The ID is a truncated **SHA-256** of the input. `from:` must be a string; pass a
non-binary and it raises. For a composite key, stringify it yourself first
(`"#{tenant}:#{email}"`) so you control the exact bytes that get hashed.

## Prefix is the namespace

The prefix is folded into the hash as the namespace, so the same string under two
prefixes produces two unrelated bodies — `usr` + `"alice@example.com"` and `org`
+ `"alice@example.com"` never collide:

```elixir
UXID.generate!(prefix: "usr", from: "alice@example.com")  # "usr_zcvt7epac…"
UXID.generate!(prefix: "org", from: "alice@example.com")  # "org_zes4c99fn…"  (unrelated)
```

Most callers pass just `prefix` + `from` and get correct scoping with zero extra
config. (There is no separate `namespace:` option; the prefix does that job. No
prefix at all hashes into the global scope.)

## The `z` marker and sort order

A deterministic body always starts with `z` (or `Z` in upper case) — Crockford
value 31, the maximum symbol. It does two jobs:

1. **Self-identifying** — a human or the decoder can see at a glance that the ID
   is hash-derived, not time-derived. `UXID.deterministic?/1` reports it, and
   `decode/1` returns `deterministic: true` with `time: nil`.
2. **Sorts last** — because `z` is the highest value, every deterministic ID
   sorts *after* every time-based ID. They cluster at the end of an index instead
   of interleaving with (and polluting) the K-sortable time range. Among
   themselves they sort in no meaningful order.

To keep `z` an unambiguous marker, compact-time encoding reserves value 31: a
compact timestamp can no longer start with `z`, which trims the compact horizon
to ~mid-2038 (standard 48-bit timestamps are unaffected). See the
[Sizes & Encoding guide](sizes.md#compact-time).

## Size and length

Deterministic bodies reuse the standard (non-compact) lengths, spending the whole
body — minus the one-character marker — on hash bits:

| Size          | Aliases      | Body length | Hash bits |
|---------------|--------------|-------------|-----------|
| `:xs`         | `:xsmall`    | 10 chars    | 45        |
| `:s`          | `:small`     | 14 chars    | 65        |
| `:m`          | `:medium`    | 18 chars    | 85        |
| `:l`          | `:large`     | 22 chars    | 105       |
| `:xl`         | `:xlarge`    | 26 chars    | 125       |

With no `:size`, generation defaults to `:xl` (125 hash bits). A deterministic ID
carries *more* distinguishing bits than the random UXID of the same size, since it
does not spend characters on a timestamp. Changing `size` changes the ID: the
same input at two sizes yields unrelated bodies, not one a truncated prefix of the
other. Case is a display concern applied at encode time — upper and lower are the
same ID, exactly as for random UXIDs.

## Properties, honestly

- **Deterministic & idempotent** — same `{namespace, name, size, case}` → same ID,
  everywhere, forever.
- **Not time-ordered** — hash order is effectively random-but-stable. These sort
  after time IDs and among themselves in no meaningful order, so do not rely on
  them for K-sortability.
- **Not a secret** — a deterministic ID is a hash of a *known* input, so it is
  exactly as guessable as that input. Anyone who knows the namespace + name can
  recompute the ID. Do **not** derive an ID from a low-entropy secret and treat
  the ID as unguessable. (This is the same caveat RFC 4122 gives for name-based
  UUIDs.)

> #### Deterministic IDs are not unguessable {: .warning}
>
> If you need an identifier an attacker cannot guess, use a random UXID (`:large`
> or `:xl`), not a deterministic one. `from:` is for stability, not secrecy.

## With Ecto

Ecto `autogenerate` is intentionally **not** wired for `from:` — there is no
per-row input available at autogenerate time. Mint the ID explicitly in
application code (typically a changeset) and store it as an ordinary string:

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email])
  |> validate_required([:email])
  |> put_deterministic_id()
end

defp put_deterministic_id(%{valid?: true, changes: %{email: email}} = changeset) do
  put_change(changeset, :id, UXID.generate!(prefix: "usr", from: email))
end

defp put_deterministic_id(changeset), do: changeset
```

The field itself is a normal `UXID` (or `:string`) column — casting and querying
are unchanged; you are just supplying the value instead of letting the datastore
or `autogenerate` mint a random one.
