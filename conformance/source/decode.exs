# Authored source for conformance/decode.json. `mix uxid.corpus` evaluates
# this file and calls the library's decoder for every case's expected
# reading; the case file itself is never edited by hand.
#
# Each case: a slug (the id is "decode/<slug>") and either `input`, the string
# to decode, or `encode`, options the generator passes to the library to
# build that string. A decode case reads the prefix, size, compact flag,
# deterministic flag and time; the random field is not read back on decode.

# 2023-11-14, well inside the current 2^40 ms window, so a decoder's clock
# recovers the full time from a compact body for years.
time = 1_700_000_000_000
pattern = <<0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x01, 0x23>>
rand = fn bytes -> binary_part(pattern, 0, bytes) end

[
  %{slug: "xl-standard", encode: [prefix: "usr", size: :xl, time: time, rand: rand.(10)]},
  %{
    slug: "xl-compact",
    encode: [prefix: "usr", size: :xl, compact_time: true, time: time, rand: rand.(10)]
  },
  %{slug: "l-standard", encode: [prefix: "usr", size: :l, time: time, rand: rand.(7)]},
  %{
    slug: "l-compact",
    encode: [prefix: "usr", size: :l, compact_time: true, time: time, rand: rand.(8)]
  },
  %{slug: "m-standard", encode: [prefix: "usr", size: :m, time: time, rand: rand.(5)]},
  # A compact m body has a standard m length (18): it decodes as standard, with
  # a time read from its first 10 characters, not the time it was built with.
  %{
    slug: "m-compact-reads-as-standard",
    encode: [prefix: "usr", size: :m, compact_time: true, time: time, rand: rand.(6)]
  },
  %{slug: "s-standard", encode: [prefix: "usr", size: :s, time: time, rand: rand.(2)]},
  %{
    slug: "s-compact",
    encode: [prefix: "usr", size: :s, compact_time: true, time: time, rand: rand.(3)]
  },
  %{slug: "xs-standard", encode: [prefix: "usr", size: :xs, time: time, rand: <<>>]},
  # A compact xs body has a standard xs length (10): the same rule as compact m.
  %{
    slug: "xs-compact-reads-as-standard",
    encode: [prefix: "usr", size: :xs, compact_time: true, time: time, rand: rand.(1)]
  },
  # A decoder accepts either case.
  %{
    slug: "xl-standard-upper",
    encode: [prefix: "usr", size: :xl, case: :upper, time: time, rand: rand.(10)]
  },
  %{slug: "xl-standard-no-prefix", encode: [size: :xl, time: time, rand: rand.(10)]},
  # The body is everything after the last delimiter; the prefix keeps the rest.
  %{slug: "s-standard-prefix-with-delimiter", input: "a_b_01hf7yat000001"},
  # The compact guard's last valid millisecond, from the window before the
  # current one: recovered by the one-window subtraction until mid-2038.
  %{
    slug: "s-compact-guard-last-valid",
    encode: [prefix: "usr", size: :s, compact_time: true, time: 1_065_151_889_407, rand: rand.(3)]
  },
  # Deterministic bodies: a size from the length, no time.
  %{slug: "deterministic-usr-xl", input: "usr_zcvt7epac0t1ebcsjfyf7cwz25"},
  %{slug: "deterministic-cus-s", input: "cus_zt9vnyfd85bff0"},
  %{slug: "deterministic-no-prefix-m", input: "zqz4cwzgyw8ks97869"},
  %{slug: "deterministic-upper-marker", input: "usr_ZCVT7EPAC0T1EBCSJFYF7CWZ25"}
]
