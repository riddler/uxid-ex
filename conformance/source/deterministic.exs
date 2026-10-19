# Authored source for conformance/deterministic.json. `mix uxid.corpus`
# evaluates this file and calls the library for every case's expected id; the
# case file itself is never edited by hand.
#
# Each case: a slug (the id is "deterministic/<slug>"), the prefix (nil for
# none), the `from` string, the size and the letter case. A case that carries
# `expected` is a golden vector: the generator refuses to write anything when
# the library's answer differs from it.

sizes = [:xs, :s, :m, :l, :xl]

# The three ids that lock the format, verbatim from guides/wire-format.md,
# "Deterministic bodies", and the deterministic test's golden vectors.
golden = [
  %{
    slug: "golden-usr-xl",
    prefix: "usr",
    from: "alice@example.com",
    size: :xl,
    case: :lower,
    expected: "usr_zcvt7epac0t1ebcsjfyf7cwz25"
  },
  %{
    slug: "golden-cus-s",
    prefix: "cus",
    from: "acme-corp",
    size: :s,
    case: :lower,
    expected: "cus_zt9vnyfd85bff0"
  },
  %{
    slug: "golden-no-prefix-m",
    prefix: nil,
    from: "alice@example.com",
    size: :m,
    case: :lower,
    expected: "zqz4cwzgyw8ks97869"
  }
]

every_size =
  for size <- sizes do
    %{slug: "usr-#{size}", prefix: "usr", from: "alice@example.com", size: size, case: :lower}
  end

others = [
  # An empty prefix and an absent prefix are the same: both hash an empty
  # prefix and emit the bare body.
  %{slug: "empty-prefix-xl", prefix: "", from: "alice@example.com", size: :xl, case: :lower},
  %{slug: "no-prefix-xl", prefix: nil, from: "alice@example.com", size: :xl, case: :lower},
  # Case is display only: the marker and the hash characters change case, the
  # hash input does not.
  %{slug: "usr-xl-upper", prefix: "usr", from: "alice@example.com", size: :xl, case: :upper},
  # The from string is hashed as its UTF-8 bytes.
  %{slug: "non-ascii-from-m", prefix: "cus", from: "café", size: :m, case: :lower}
]

golden ++ every_size ++ others
