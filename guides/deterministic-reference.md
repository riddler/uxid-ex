# Deterministic IDs reference

The option that switches generation into deterministic mode, and the body
lengths and hash widths it produces. What the scheme is for, and what it does
and does not promise, is on the [Deterministic IDs](deterministic.md) page.

## The `from:` option

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

## Size and length

Deterministic bodies reuse the standard (non-compact) lengths, spending the whole
body - minus the one-character marker - on hash bits:

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
other. Case is a display concern applied at encode time - upper and lower are the
same ID, exactly as for random UXIDs.
