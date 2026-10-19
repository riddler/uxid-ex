# Authored source for conformance/encode.json. `mix uxid.corpus` evaluates
# this file and calls the library for every case's expected id; the case file
# itself is never edited by hand.
#
# Each case: a slug (the id is "encode/<slug>"), the prefix (nil for none),
# the size, the compact flag, the letter case, the time in milliseconds and
# the random field as lowercase hex, exactly the random width of the size.

# Random bytes per size, standard and compact (guides/wire-format.md, "Sizes").
widths = %{
  {:xs, false} => 0,
  {:s, false} => 2,
  {:m, false} => 5,
  {:l, false} => 7,
  {:xl, false} => 10,
  {:xs, true} => 1,
  {:s, true} => 3,
  {:m, true} => 6,
  {:l, true} => 8,
  {:xl, true} => 10
}

sizes = [:xs, :s, :m, :l, :xl]

# 2023-11-14, well inside the current 2^40 ms window, so a decoder's clock
# recovers the full time from a compact body for years.
time = 1_700_000_000_000

pattern = "0123456789abcdef0123"
mode = fn compact -> if compact, do: "compact", else: "standard" end

# Every size, standard and compact, lower and upper case.
every_size =
  for size <- sizes, compact <- [false, true], letter_case <- [:lower, :upper] do
    %{
      slug: "#{size}-#{mode.(compact)}-#{letter_case}",
      prefix: "usr",
      size: size,
      compact: compact,
      case: letter_case,
      time: time,
      rand: String.slice(pattern, 0, 2 * widths[{size, compact}])
    }
  end

# The random field all ones: the last group of a width that is not a multiple
# of 5 bits is written as its raw value (the partial-group rule), so a 2-byte
# field ends in `1`, a 1-byte field in `7` and a 3-byte field in `f`.
partial_groups =
  for size <- sizes, compact <- [false, true], widths[{size, compact}] > 0 do
    %{
      slug: "#{size}-#{mode.(compact)}-rand-all-ones",
      prefix: "cus",
      size: size,
      compact: compact,
      case: :lower,
      time: time,
      rand: String.duplicate("ff", widths[{size, compact}])
    }
  end

times = [
  # The standard time's first group is 3 bits: the smallest and the largest
  # 48-bit time.
  %{
    slug: "xs-standard-time-zero",
    prefix: nil,
    size: :xs,
    compact: false,
    case: :lower,
    time: 0,
    rand: ""
  },
  %{
    slug: "xs-standard-time-max",
    prefix: nil,
    size: :xs,
    compact: false,
    case: :lower,
    time: 281_474_976_710_655,
    rand: ""
  },
  # The compact guard's last valid millisecond: low 40 bits of 31 x 2^35 - 1,
  # the largest compact time field (first character value 30). This is the
  # time in the window before the current one, which a decoder recovers by
  # the one-window subtraction until mid-2038; the same body in the current
  # window is the mid-2038 millisecond.
  %{
    slug: "s-compact-guard-last-valid",
    prefix: "usr",
    size: :s,
    compact: true,
    case: :lower,
    time: 1_065_151_889_407,
    rand: "012345"
  }
]

prefixes = [
  %{
    slug: "xl-standard-no-prefix",
    prefix: nil,
    size: :xl,
    compact: false,
    case: :lower,
    time: time,
    rand: pattern
  },
  # An empty prefix is no prefix: the bare body, no delimiter.
  %{
    slug: "xl-standard-empty-prefix",
    prefix: "",
    size: :xl,
    compact: false,
    case: :lower,
    time: time,
    rand: pattern
  },
  # A prefix may contain the delimiter.
  %{
    slug: "s-standard-prefix-with-delimiter",
    prefix: "a_b",
    size: :s,
    compact: false,
    case: :lower,
    time: time,
    rand: "0123"
  }
]

every_size ++ partial_groups ++ times ++ prefixes
