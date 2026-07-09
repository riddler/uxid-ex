defmodule UXID.MonotonicTest do
  use ExUnit.Case, async: true

  alias UXID.Monotonic

  describe "next/3" do
    test "seeds with full random bytes on the first call" do
      {time, rand} = Monotonic.next("evt", 2, 1000)
      assert time == 1000
      assert byte_size(rand) == 2
    end

    test "increments by 1 within the same millisecond" do
      {_t, r1} = Monotonic.next("evt", 3, 5000)
      {_t, r2} = Monotonic.next("evt", 3, 5000)

      assert :binary.decode_unsigned(r2) == :binary.decode_unsigned(r1) + 1
      assert r2 > r1
    end

    test "a same-ms burst is strictly increasing and unique" do
      rands =
        for _ <- 1..100 do
          {_t, r} = Monotonic.next("burst", 4, 9000)
          r
        end

      assert length(Enum.uniq(rands)) == 100
      assert rands == Enum.sort(rands)
    end

    test "reseeds (does not just +1) when the millisecond advances" do
      {_t, r1} = Monotonic.next("seed", 4, 10_000)
      {_t, r2} = Monotonic.next("seed", 4, 10_001)

      # A fresh 32-bit seed landing exactly on r1 + 1 is a 1-in-2^32 event.
      refute :binary.decode_unsigned(r2) == :binary.decode_unsigned(r1) + 1
    end

    test "clock moving backward keeps the last time and still increments" do
      {t1, r1} = Monotonic.next("back", 3, 20_000)
      {t2, r2} = Monotonic.next("back", 3, 19_995)

      assert t2 == t1
      assert :binary.decode_unsigned(r2) == :binary.decode_unsigned(r1) + 1
    end

    test "overflow within a ms spins the time forward and reseeds" do
      # 1-byte field = 256 values (0..255).
      time = 30_000
      {^time, first} = Monotonic.next("of", 1, time)
      start = :binary.decode_unsigned(first)

      # Exhaust the remaining capacity of the field within this ms.
      for _ <- 1..(255 - start) do
        {^time, _} = Monotonic.next("of", 1, time)
      end

      # The next call overflows: time bumps forward, field reseeds.
      {bumped_time, _reseeded} = Monotonic.next("of", 1, time)
      assert bumped_time == time + 1
    end

    test "distinct prefixes maintain independent sequences" do
      {_t, a} = Monotonic.next("a", 2, 40_000)
      {_t, b} = Monotonic.next("b", 2, 40_000)
      {_t, a2} = Monotonic.next("a", 2, 40_000)

      assert :binary.decode_unsigned(a2) == :binary.decode_unsigned(a) + 1
      # b's sequence is unaffected by a's increments.
      assert byte_size(b) == 2
    end

    test "distinct rand_sizes under one prefix do not corrupt each other" do
      {_t, small} = Monotonic.next("p", 2, 50_000)
      {_t, large} = Monotonic.next("p", 4, 50_000)

      assert byte_size(small) == 2
      assert byte_size(large) == 4
    end

    test "nil prefix is a valid, independent sequence" do
      {_t, r1} = Monotonic.next(nil, 2, 60_000)
      {_t, r2} = Monotonic.next(nil, 2, 60_000)
      assert :binary.decode_unsigned(r2) == :binary.decode_unsigned(r1) + 1
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
      {_t, r1} = Monotonic.next("iso", 2, 80_000)
      parent = self()

      spawn(fn ->
        {_t, other} = Monotonic.next("iso", 2, 80_000)
        send(parent, {:child, other})
      end)

      child =
        receive do
          {:child, other} -> other
        after
          1000 -> flunk("child process did not respond")
        end

      # The child starts its own sequence — it is not r1 + 1.
      refute :binary.decode_unsigned(child) == :binary.decode_unsigned(r1) + 1
    end
  end

  # Raw random integer of the field a given generation would emit. Uses new/1 so
  # tests can assert exact increment-vs-reseed on the counter, which is not
  # recoverable from the encoded string (the random field is never decoded).
  defp rand_int(opts) do
    {:ok, codec} = UXID.new(opts)
    :binary.decode_unsigned(codec.rand)
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

    test "a new millisecond reseeds instead of continuing the +1 sequence" do
      first = rand_int(size: :medium, time: 1_700_000_100_000, monotonic: true)
      later = rand_int(size: :medium, time: 1_700_000_100_001, monotonic: true)

      # A fresh 40-bit seed landing exactly on first + 1 is a 1-in-2^40 event.
      refute later == first + 1
    end

    test "clock moving backward still increases and never emits a smaller time" do
      {:ok, c1} = UXID.new(size: :small, time: 1_700_000_200_000, monotonic: true)
      {:ok, c2} = UXID.new(size: :small, time: 1_700_000_199_995, monotonic: true)

      assert c2.time == c1.time
      assert c2.string > c1.string
    end

    test "non-monotonic generation is unaffected (no exact +1 relationship)" do
      t = 1_700_000_300_000
      a = rand_int(size: :medium, time: t)
      b = rand_int(size: :medium, time: t)
      refute b == a + 1
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
      t = 1_700_000_600_000

      small_a = rand_int(size: :small, time: t, monotonic: [:small])
      small_b = rand_int(size: :small, time: t, monotonic: [:small])
      assert small_b == small_a + 1

      s_a = rand_int(size: :s, time: t, monotonic: [:small])
      s_b = rand_int(size: :s, time: t, monotonic: [:small])
      assert s_b == s_a + 1

      med_a = rand_int(size: :medium, time: t, monotonic: [:small])
      med_b = rand_int(size: :medium, time: t, monotonic: [:small])
      refute med_b == med_a + 1
    end
  end

  describe "monotonic precedence: global vs per-call" do
    test "per-call monotonic: false overrides global true" do
      Application.put_env(:uxid, :monotonic, true)
      on_exit(fn -> Application.delete_env(:uxid, :monotonic) end)

      t = 1_700_000_700_000
      a = rand_int(size: :medium, time: t, monotonic: false)
      b = rand_int(size: :medium, time: t, monotonic: false)
      refute b == a + 1
    end

    test "per-call monotonic: true applies when global is off" do
      Application.put_env(:uxid, :monotonic, false)
      on_exit(fn -> Application.delete_env(:uxid, :monotonic) end)

      t = 1_700_000_700_001
      a = rand_int(size: :medium, time: t, monotonic: true)
      b = rand_int(size: :medium, time: t, monotonic: true)
      assert b == a + 1
    end

    test "global list config applies alias-aware when no per-call option is given" do
      Application.put_env(:uxid, :monotonic, [:small, :medium])
      on_exit(fn -> Application.delete_env(:uxid, :monotonic) end)

      t = 1_700_000_700_002
      a = rand_int(size: :m, time: t)
      b = rand_int(size: :m, time: t)
      assert b == a + 1

      # A size outside the list is unaffected.
      la = rand_int(size: :large, time: t)
      lb = rand_int(size: :large, time: t)
      refute lb == la + 1
    end
  end
end
