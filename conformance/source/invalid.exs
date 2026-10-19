# Authored source for conformance/invalid.json. `mix uxid.corpus` evaluates
# this file and calls the library for every case; the case file itself is
# never edited by hand.
#
# Each case: a slug (the id is "invalid/<slug>"), the error it expects, and
# either `decode`, a string the decoder refuses, or `generate`, options the
# library refuses to build an id from. The generator checks a decode case's
# error against the reason UXID.decode/1 gives, and a generate case's against
# the ArgumentError the library raises, before it writes the case.

# 2023-11-14, well inside the current 2^40 ms window.
time = 1_700_000_000_000

# A well-formed standard xl body (time 1700000000000, random field 00..09) and
# a well-formed deterministic xl body, to break one rule at a time.
body = "01hf7yat00000g40r40m30e209"
deterministic = "zcvt7epac0t1ebcsjfyf7cwz25"

at = fn string, index, char ->
  String.slice(string, 0, index) <> char <> String.slice(string, (index + 1)..-1//1)
end

[
  # empty: no body at all.
  %{slug: "decode-empty-string", decode: "", expected_error: :empty},
  %{slug: "decode-ends-in-delimiter", decode: "usr_", expected_error: :empty},
  %{
    slug: "decode-prefix-with-delimiter-ends-in-delimiter",
    decode: "a_b_",
    expected_error: :empty
  },
  %{slug: "decode-delimiter-only", decode: "_", expected_error: :empty},

  # invalid_length: a body length in bytes outside the length table.
  %{
    slug: "decode-length-11",
    decode: "usr_" <> String.slice(body, 0, 11),
    expected_error: :invalid_length
  },
  %{
    slug: "decode-length-25",
    decode: "usr_" <> String.slice(body, 0, 25),
    expected_error: :invalid_length
  },
  %{slug: "decode-length-27", decode: "usr_" <> body <> "0", expected_error: :invalid_length},
  %{slug: "decode-no-delimiter-short", decode: "usr", expected_error: :invalid_length},

  # invalid_character: a well-formed length with a character outside the
  # alphabet, in the time characters, in the random characters, and in a
  # deterministic body.
  %{
    slug: "decode-character-in-time",
    decode: "usr_" <> at.(body, 3, "u"),
    expected_error: :invalid_character
  },
  %{
    slug: "decode-character-in-random",
    decode: "usr_" <> at.(body, 15, "l"),
    expected_error: :invalid_character
  },
  %{
    slug: "decode-upper-o-in-random",
    decode: "usr_" <> at.(body, 20, "O"),
    expected_error: :invalid_character
  },
  %{
    slug: "decode-hyphen-in-body",
    decode: "usr_" <> at.(body, 10, "-"),
    expected_error: :invalid_character
  },
  %{
    slug: "decode-character-in-deterministic",
    decode: "usr_" <> at.(deterministic, 24, "i"),
    expected_error: :invalid_character
  },

  # Lengths are counted in bytes. A two-byte character in place of two ASCII
  # characters keeps a table length in bytes (26) at 25 characters, and is
  # refused for the character; added to a 25-character body it makes 27 bytes
  # at 26 characters, and is refused for the length.
  %{
    slug: "decode-non-ascii-table-length",
    decode: String.slice(body, 0, 24) <> "é",
    expected_error: :invalid_character
  },
  %{
    slug: "decode-non-ascii-off-table-length",
    decode: String.slice(body, 0, 25) <> "é",
    expected_error: :invalid_length
  },

  # A body failing both rules is refused for the length, the first checked.
  %{
    slug: "decode-length-and-character",
    decode: "usr_" <> String.slice(body, 0, 10) <> "u",
    expected_error: :invalid_length
  },

  # Generation errors, named by the option that caused each.
  # A compact time whose first character would be the marker: the guard's
  # first millisecond in the current 2^40 ms window (mid-2038) and in the one
  # before.
  %{
    slug: "generate-compact-time-at-guard",
    generate: [
      prefix: "usr",
      size: :s,
      compact_time: true,
      time: 2_164_663_517_184,
      rand: <<1, 2, 3>>
    ],
    expected_error: :compact_time_out_of_range
  },
  %{
    slug: "generate-compact-time-at-guard-previous-window",
    generate: [
      prefix: "usr",
      size: :s,
      compact_time: true,
      time: 1_065_151_889_408,
      rand: <<1, 2, 3>>
    ],
    expected_error: :compact_time_out_of_range
  },
  # rand: of a width other than the call's random field.
  %{
    slug: "generate-rand-too-wide",
    generate: [prefix: "usr", size: :s, time: time, rand: <<1, 2, 3>>],
    expected_error: :rand_width_mismatch
  },
  %{
    slug: "generate-rand-too-narrow",
    generate: [prefix: "usr", size: :xl, time: time, rand: <<1, 2, 3, 4, 5, 6, 7, 8, 9>>],
    expected_error: :rand_width_mismatch
  },
  %{
    slug: "generate-rand-on-xs-standard",
    generate: [prefix: "usr", size: :xs, time: time, rand: <<1>>],
    expected_error: :rand_width_mismatch
  },
  # An explicit random width above 10 bytes.
  %{
    slug: "generate-rand-size-11",
    generate: [prefix: "usr", size: :xl, rand_size: 11, time: time],
    expected_error: :rand_size_too_large
  },
  # A deterministic body asked for with monotonic generation.
  %{
    slug: "generate-from-with-monotonic",
    generate: [prefix: "usr", from: "alice@example.com", monotonic: true],
    expected_error: :from_with_monotonic
  },
  # rand: with a deterministic body, and with monotonic generation.
  %{
    slug: "generate-rand-with-from",
    generate: [prefix: "usr", from: "alice@example.com", rand: <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9>>],
    expected_error: :rand_with_from
  },
  %{
    slug: "generate-rand-with-monotonic",
    generate: [prefix: "usr", size: :s, time: time, monotonic: true, rand: <<1, 2>>],
    expected_error: :rand_with_monotonic
  }
]
