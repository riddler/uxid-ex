defmodule UXID.MonotonicTest do
  # async: false — the precedence tests mutate global config (Application.put_env
  # for :monotonic). ExUnit never runs a sync module concurrently with async ones,
  # so this keeps that global from bleeding into other tests mid-run.
  use ExUnit.Case, async: false

  import Bitwise

  alias UXID.Monotonic

  describe "next/3" do
    test "seeds with full random bytes on the first call" do
      {time, rand} = Monotonic.next("evt", 2, 1000)
      assert time == 1000
      assert byte_size(rand) == 2
    end

    test "advances by a positive step within the same millisecond" do
      {_kept, r1, r2} = stepped_pair("evt", 3, 5000, 5000)

      # Random step is in [1, 2^12] for a 3-byte field: strictly greater, and
      # within the forward step window (never a full reseed within the ms).
      u1 = :binary.decode_unsigned(r1)
      u2 = :binary.decode_unsigned(r2)
      assert u2 > u1
      assert (u2 - u1) in 1..(1 <<< 12)
      assert r2 > r1
    end

    test "a same-ms burst is strictly increasing and unique" do
      # A high random seed can overflow the field within the burst, which spins
      # the time forward 1ms and reseeds — those draws are a new run, not the same
      # ms. Group by emitted time and assert the per-ms guarantee on each run.
      draws =
        for _ <- 1..100 do
          Monotonic.next("burst", 4, 9000)
        end

      runs =
        draws
        |> Enum.chunk_by(fn {t, _r} -> t end)
        |> Enum.map(fn run -> Enum.map(run, fn {_t, r} -> r end) end)

      assert Enum.all?(runs, fn rands ->
               rands == Enum.sort(rands) and length(Enum.uniq(rands)) == length(rands)
             end)
    end

    test "steps vary and stay within [1, 2^(bits/2)] (not a constant +1)" do
      # 2-byte field: step_bits = 8, so same-ms gaps lie in [1, 256]. A constant
      # +1 would be the old guessable behavior; over the burst at least one gap
      # must exceed 1. A high random seed can overflow the field mid-burst, which
      # spins the time forward 1ms and reseeds (the gap across that boundary is a
      # fresh seed, not a step), so compare only consecutive draws that stayed in
      # the same millisecond.
      draws =
        for _ <- 1..50 do
          {t, r} = Monotonic.next("vary", 2, 90_000)
          {t, :binary.decode_unsigned(r)}
        end

      gaps =
        draws
        |> Enum.zip(tl(draws))
        |> Enum.filter(fn {{t1, _}, {t2, _}} -> t1 == t2 end)
        |> Enum.map(fn {{_, a}, {_, b}} -> b - a end)

      assert gaps != []
      assert Enum.all?(gaps, &(&1 in 1..256))
      assert Enum.any?(gaps, &(&1 > 1))
    end

    test "reseeds (does not continue the step sequence) when the millisecond advances" do
      {_t, r1} = Monotonic.next("seed", 4, 10_000)
      {_t, r2} = Monotonic.next("seed", 4, 10_001)

      u1 = :binary.decode_unsigned(r1)
      u2 = :binary.decode_unsigned(r2)

      # Continuing would land in the forward step window (u1, u1 + 2^16]. A fresh
      # 32-bit seed doing so is a ~1-in-2^16 event, so treat it as a reseed.
      refute u2 in (u1 + 1)..(u1 + (1 <<< 16))
    end

    test "clock moving backward keeps the last time and still advances" do
      {kept, r1, r2} = stepped_pair("back", 3, 20_000, 19_995)

      # The backward clock (19_995 < 20_000) keeps the earlier last_time and still
      # advances the counter by a forward step.
      assert kept == 20_000
      assert :binary.decode_unsigned(r2) > :binary.decode_unsigned(r1)
    end

    test "overflow within a ms spins the time forward and reseeds" do
      # 1-byte field = 256 values; random steps of [1, 16] exhaust it within a
      # few dozen draws. Draw until the time bumps forward.
      time = 30_000

      bumped =
        Enum.reduce_while(1..1000, nil, fn _, _ ->
          case Monotonic.next("of", 1, time) do
            {^time, _} -> {:cont, nil}
            {t, _} when t > time -> {:halt, t}
          end
        end)

      assert bumped == time + 1
    end

    test "distinct prefixes maintain independent sequences" do
      {_kept, a, a2} = stepped_pair("a", 2, 40_000, 40_000)
      {_t, b} = Monotonic.next("b", 2, 40_000)

      assert :binary.decode_unsigned(a2) > :binary.decode_unsigned(a)
      # b lives under a separate key ({prefix, rand_size}), so a's advances leave
      # it untouched — a fresh, correctly sized seed.
      assert byte_size(b) == 2
    end

    test "distinct rand_sizes under one prefix do not corrupt each other" do
      {_t, small} = Monotonic.next("p", 2, 50_000)
      {_t, large} = Monotonic.next("p", 4, 50_000)

      assert byte_size(small) == 2
      assert byte_size(large) == 4
    end

    test "nil prefix is a valid, independent sequence" do
      {_kept, r1, r2} = stepped_pair(nil, 2, 60_000, 60_000)
      assert :binary.decode_unsigned(r2) > :binary.decode_unsigned(r1)
    end
  end

  describe "reset/2" do
    test "clears the counter so the next call reseeds" do
      {_t, _r1} = Monotonic.next("reset", 4, 70_000)
      assert Monotonic.reset("reset", 4)

      # After reset the same ms behaves like a first call (fresh seed, not +1).
      # We can't assert the value, but we can assert it does not raise and is sized.
      {t, r} = Monotonic.next("reset", 4, 70_000)
      assert t == 70_000
      assert byte_size(r) == 4
    end
  end

  describe "process isolation" do
    test "a spawned process gets an independent sequence" do
      # Use a 4-byte field so a fresh, independent child seed coincidentally
      # landing in the parent's forward step window is a ~1-in-2^16 event (as in
      # the "reseeds when the millisecond advances" test), not ~1-in-256.
      {_t, r1} = Monotonic.next("iso", 4, 80_000)
      parent = self()

      spawn(fn ->
        {_t, other} = Monotonic.next("iso", 4, 80_000)
        send(parent, {:child, other})
      end)

      child =
        receive do
          {:child, other} -> other
        after
          1000 -> flunk("child process did not respond")
        end

      # The child starts its own sequence (a fresh seed), not a continuation of
      # the parent's — so it does not land in the parent's forward step window.
      u1 = :binary.decode_unsigned(r1)
      refute :binary.decode_unsigned(child) in (u1 + 1)..(u1 + (1 <<< 16))
    end
  end

  # Raw random integer of the field a given generation would emit. Uses new/1 so
  # tests can assert exact increment-vs-reseed on the counter, which is not
  # recoverable from the encoded string (the random field is never decoded).
  defp rand_int(opts) do
    {:ok, codec} = UXID.new(opts)
    :binary.decode_unsigned(codec.rand)
  end

  # The emitted `{time, rand_int}` pair. The time matters because a same-ms burst
  # that overflows the field spins the time forward 1ms and reseeds (see
  # UXID.Monotonic) — those draws belong to a new millisecond, not the same run.
  defp rand_pair(opts) do
    {:ok, codec} = UXID.new(opts)
    {codec.time, :binary.decode_unsigned(codec.rand)}
  end

  # A first draw plus a second consecutive draw that stayed in the same emitted
  # millisecond — a pure forward step, no overflow reseed. `t2` is the wall-clock
  # handed to the second draw; pass `t2 < t1` to model a backward clock. A high
  # random seed occasionally overflows the field on the step, which the module
  # handles by spinning the time forward and reseeding; retry past that rare case
  # so the forward-step assertions stay deterministic. Returns `{kept_time, r1, r2}`.
  defp stepped_pair(prefix, rand_size, t1, t2) do
    Monotonic.reset(prefix, rand_size)
    {kept, r1} = Monotonic.next(prefix, rand_size, t1)

    case Monotonic.next(prefix, rand_size, t2) do
      {^kept, r2} -> {kept, r1, r2}
      _overflowed -> stepped_pair(prefix, rand_size, t1, t2)
    end
  end

  # Decides whether `opts` yields a monotonic sequence. A monotonic burst is
  # strictly increasing and unique *within a millisecond*; a random one shares one
  # ms and is sorted only by chance (~1/n!). A 20-draw burst makes false positives
  # ~1/20! — effectively zero. We group draws by their emitted ms and check each
  # run on its own: a high random seed can overflow the field mid-burst, which
  # starts a fresh run in the next ms, so comparing the raw ints across that
  # boundary would spuriously fail.
  defp monotonic?(opts) do
    runs =
      for(_ <- 1..20, do: rand_pair(opts))
      |> Enum.chunk_by(fn {time, _int} -> time end)
      |> Enum.map(fn run -> Enum.map(run, fn {_time, int} -> int end) end)

    Enum.all?(runs, fn ints -> ints == Enum.sort(ints) and ints == Enum.uniq(ints) end)
  end

  describe "monotonic generation via generate!/1" do
    test "two same-ms IDs increment and sort strictly after" do
      t = 1_700_000_000_000
      a = UXID.generate!(size: :small, time: t, monotonic: true)
      b = UXID.generate!(size: :small, time: t, monotonic: true)

      assert b > a
      assert String.length(a) == String.length(b)
    end

    test "a same-ms burst is unique and strictly increasing" do
      t = 1_700_000_000_001

      ids =
        for _ <- 1..200, do: UXID.generate!(size: :medium, time: t, monotonic: true)

      assert length(Enum.uniq(ids)) == 200
      assert ids == Enum.sort(ids)
    end

    test "a new millisecond reseeds instead of continuing the step sequence" do
      first = rand_int(size: :medium, time: 1_700_000_100_000, monotonic: true)
      later = rand_int(size: :medium, time: 1_700_000_100_001, monotonic: true)

      # Continuing would land in the forward step window (first, first + 2^20]. A
      # fresh 40-bit seed doing so is a ~1-in-2^20 event, so treat it as a reseed.
      refute later in (first + 1)..(first + (1 <<< 20))
    end

    test "clock moving backward still increases and never emits a smaller time" do
      {:ok, c1} = UXID.new(size: :small, time: 1_700_000_200_000, monotonic: true)
      {:ok, c2} = UXID.new(size: :small, time: 1_700_000_199_995, monotonic: true)

      # The backward clock never emits a smaller time: normally it keeps c1's time,
      # and in the rare case the field overflows on the step it spins 1ms forward —
      # never backward. (Exact keep-the-last-time is covered at the Monotonic unit
      # level.) The encoded ID still strictly increases either way.
      assert c2.time >= c1.time
      assert c2.string > c1.string
    end

    test "non-monotonic generation is unaffected (not a monotonic sequence)" do
      refute monotonic?(size: :medium, time: 1_700_000_300_000)
    end
  end

  describe "monotonic :xs auto-compact" do
    test "generate!/1 produces a compact, incrementing body" do
      t = 1_700_000_400_000
      a = UXID.generate!(size: :xs, time: t, monotonic: true)
      b = UXID.generate!(size: :xs, time: t, monotonic: true)

      # Compact :xs body = 8 time + 2 rand = 10 chars.
      assert String.length(a) == 10
      assert b > a
    end

    test "explicit compact_time: false on :xs with monotonic raises" do
      assert_raise ArgumentError, ~r/monotonic mode needs a random field/, fn ->
        UXID.generate!(size: :xs, time: 1_700_000_400_001, monotonic: true, compact_time: false)
      end
    end
  end

  describe "monotonic overflow within a millisecond" do
    test "bumps the timestamp forward while staying unique and ordered" do
      t = 1_700_000_500_000

      # 1-byte field = 256 values, seeded at a random offset, so a 300-draw burst
      # in one ms overflows at least once and spins the timestamp forward.
      codecs =
        for _ <- 1..300 do
          {:ok, codec} = UXID.new(rand_size: 1, time: t, monotonic: true)
          codec
        end

      times = Enum.map(codecs, & &1.time)
      strings = Enum.map(codecs, & &1.string)

      assert Enum.min(times) == t
      assert Enum.max(times) >= t + 1
      assert length(Enum.uniq(strings)) == 300
      assert strings == Enum.sort(strings)
    end
  end

  describe "monotonic list config (alias-aware)" do
    test "[:small] applies to both :small and :s but not :medium" do
      assert monotonic?(size: :small, time: 1_700_000_600_000, monotonic: [:small])
      assert monotonic?(size: :s, time: 1_700_000_600_001, monotonic: [:small])
      refute monotonic?(size: :medium, time: 1_700_000_600_002, monotonic: [:small])
    end
  end

  describe "monotonic precedence: global vs per-call" do
    test "per-call monotonic: false overrides global true" do
      Application.put_env(:uxid, :monotonic, true)
      on_exit(fn -> Application.delete_env(:uxid, :monotonic) end)

      refute monotonic?(size: :medium, time: 1_700_000_700_000, monotonic: false)
    end

    test "per-call monotonic: true applies when global is off" do
      Application.put_env(:uxid, :monotonic, false)
      on_exit(fn -> Application.delete_env(:uxid, :monotonic) end)

      assert monotonic?(size: :medium, time: 1_700_000_700_001, monotonic: true)
    end

    test "global list config applies alias-aware when no per-call option is given" do
      Application.put_env(:uxid, :monotonic, [:small, :medium])
      on_exit(fn -> Application.delete_env(:uxid, :monotonic) end)

      assert monotonic?(size: :m, time: 1_700_000_700_002)

      # A size outside the list is unaffected.
      refute monotonic?(size: :large, time: 1_700_000_700_003)
    end
  end
end
