# Ecto Integration

UXID implements `Ecto.ParameterizedType`, so a UXID column is just a `:string`
(text) column with `UXID` as the field type. Ecto is an optional dependency —
UXID only uses it when your app already depends on it.

## Fields and primary keys

Set the field type to `UXID` and pass the same options you'd give
`UXID.generate!/1` (`:prefix`, `:size`, `:compact_time`, `:monotonic`, …).
`autogenerate: true` mints a value on insert when the field is blank.

```elixir
defmodule YourApp.User do
  use Ecto.Schema

  @primary_key {:id, UXID, autogenerate: true, prefix: "usr", size: :medium}
  schema "users" do
    field :api_key,    UXID, autogenerate: true, prefix: "apikey", size: :small, compact_time: true
    field :api_secret, UXID, autogenerate: true, prefix: "apisecret", size: :xlarge
  end
end
```

Because UXIDs are strings, use a text primary-key column and matching foreign
keys in your migrations:

```elixir
create table(:users, primary_key: false) do
  add :id, :string, primary_key: true
  timestamps()
end

create table(:posts, primary_key: false) do
  add :id, :string, primary_key: true
  add :user_id, :string
end
```

Set `@foreign_key_type UXID` (or `:string`) on schemas that reference UXID-keyed
tables so associations cast correctly.

## Strict validation

By default `cast/2` accepts any binary unchanged, which is ideal while a schema
still holds a mix of legacy identifiers. Opt a field into strict validation with
`validate: true`. A value must then be either:

- a structurally valid UXID carrying the field's configured `:prefix`, or
- a legacy bare UUID string (canonical 36-character form).

Anything else — an empty string, the wrong prefix, non–Base32 characters — casts
to `:error`.

```elixir
@primary_key {:id, UXID, autogenerate: true, prefix: "org", size: :medium, validate: true}
schema "organizations" do
  field :owner_org_id, UXID, prefix: "org", validate: true
end
```

## UUID coexistence and migrating a column

UUID coexistence is **on by default** so a table can migrate its column type from
`uuid` to `text` without rewriting existing rows: old UUID values keep casting
while new rows get UXIDs. Once a table holds only UXIDs, turn it off with
`allow_uuid: false` to reject stray UUIDs:

```elixir
field :id, UXID, prefix: "org", validate: true, allow_uuid: false
```

## Validating a string without Ecto

`UXID.valid?/2` checks a string's *structure* (prefix + Crockford Base32 body),
independent of Ecto:

```elixir
UXID.valid?("org_01emdgjf0dqxqj8fm78xe97y3h")                 # => true
UXID.valid?("org_01emdgjf0dqxqj8fm78xe97y3h", prefix: "usr")  # => false
UXID.valid?("not-a-uxid")                                     # => false
```

It validates structure, not authenticity, and deliberately does **not** accept
bare UUIDs — that coexistence lives only in `cast/2`. To centralize the
`prefix`/`size`/`validate`/`allow_uuid` options for a field so they live in one
place, see the [Prefix Registry guide](registry.md) and its `field_opts/1` hook.
