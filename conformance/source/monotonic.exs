# Authored source for conformance/monotonic.json. `mix uxid.corpus` evaluates
# this file, replays every case's draws through the monotonic rule and calls
# the library with `time:` and `rand:` for every expected id; the case file
# itself is never edited by hand.
#
# Each case: a slug (the id is "monotonic/<slug>"), the prefix (nil for
# none), the size, the compact flag, the time of every call in milliseconds,
# and the draws: `initial_seed`, the first id's random field as an unsigned
# integer; `steps`, one per later id, each from 1 to 2^(4w) for a field of w
# bytes; and `overflow_seed`, the fresh random field an overflow takes, when a
# step overflows the field. No time is later than the last id's time: that
# call would draw a fresh seed the case has no field for.

# 2023-11-14, well inside the current 2^40 ms window.
t = 1_700_000_000_000

[
  # Same millisecond: every id keeps the time and steps up, one step at its
  # largest (2^40 for the 10-byte field) and one at its smallest.
  %{
    slug: "xl-same-millisecond",
    prefix: "usr",
    size: :xl,
    compact: false,
    times: [t, t, t, t],
    initial_seed: 123_456_789,
    steps: [1, 1_099_511_627_776, 42]
  },
  # The clock moves back: the ids keep the last time, not the call's.
  %{
    slug: "m-clock-moves-back",
    prefix: "usr",
    size: :m,
    compact: false,
    times: [t, t - 1, t - 10, t],
    initial_seed: 1_000,
    steps: [5, 1_048_576, 7]
  },
  # An overflow: the third step carries the 2-byte field past 65535, so that id
  # takes the last time plus one and the overflow seed; the later ids keep that
  # bumped time, a call at it included, and step from the new seed.
  %{
    slug: "s-overflow-bumps-time",
    prefix: "usr",
    size: :s,
    compact: false,
    times: [t, t, t, t, t, t + 1],
    initial_seed: 65_000,
    steps: [200, 250, 100, 7, 3],
    overflow_seed: 1_234
  },
  # A monotonic xs is compact (a 1-byte field, steps up to 16): the field
  # reaches its largest value, 255, and the next step overflows on a call
  # whose clock has moved back.
  %{
    slug: "xs-compact-overflow-clock-back",
    prefix: "usr",
    size: :xs,
    compact: true,
    times: [t, t, t - 1],
    initial_seed: 250,
    steps: [5, 16],
    overflow_seed: 9
  },
  # One id: only the seed.
  %{
    slug: "l-compact-single",
    prefix: "usr",
    size: :l,
    compact: true,
    times: [t],
    initial_seed: 0,
    steps: []
  },
  # No prefix, a compact 3-byte field and the largest step (2^12).
  %{
    slug: "s-compact-no-prefix-largest-step",
    prefix: nil,
    size: :s,
    compact: true,
    times: [t, t],
    initial_seed: 0,
    steps: [4_096]
  }
]
