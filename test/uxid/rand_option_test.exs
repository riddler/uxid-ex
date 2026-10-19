defmodule UXID.RandOptionTest do
  use ExUnit.Case, async: true

  alias UXID.Codec

  @time 1_700_000_000_000

  # Crockford Base32, lower case, written out here so the expected bodies do
  # not come from the encoder under test.
  @alphabet ~c"0123456789abcdefghjkmnpqrstvwxyz"

  # The random field's encoding: 5 bits per character, the last character
  # carrying whatever bits remain (as the encoder lays them out).
  defp crockford(<<>>), do: ""
  defp crockford(<<v::5, rest::bitstring>>), do: <<Enum.at(@alphabet, v)>> <> crockford(rest)

  defp crockford(tail) when is_bitstring(tail) do
    bits = bit_size(tail)
    <<v::size(bits)>> = tail
    <<Enum.at(@alphabet, v)>>
  end

  defp bytes(0), do: <<>>
  defp bytes(n), do: :binary.list_to_bin(Enum.map(1..n, &rem(&1 * 37 + 11, 256)))

  # {size, compact_time, effective rand_size}
  @widths [
    {:xs, false, 0},
    {:s, false, 2},
    {:m, false, 5},
    {:l, false, 7},
    {:xl, false, 10},
    {nil, false, 10},
    {:xs, true, 1},
    {:s, true, 3},
    {:m, true, 6},
    {:l, true, 8},
    {:xl, true, 10}
  ]

  describe "rand: fills the random field verbatim" do
    # Sabotage: put_rand/2 returns the resolved codec without the caller's
    # bytes (rand left nil) -> fresh random bytes are drawn and every body's
    # random part differs from the expected encoding.
    test "for every size, standard and compact" do
      for {size, compact, width} <- @widths do
        rand = bytes(width)
        opts = [prefix: "usr", time: @time, size: size, compact_time: compact]

        {:ok, %Codec{string: plain}} = UXID.new(opts)
        {:ok, %Codec{} = codec} = UXID.new([rand: rand] ++ opts)

        time_chars = if compact, do: 8, else: 10
        "usr_" <> body = codec.string
        "usr_" <> plain_body = plain

        assert codec.rand == rand, "size #{inspect(size)} compact #{compact}"
        assert String.slice(body, 0, time_chars) == String.slice(plain_body, 0, time_chars)
        assert String.slice(body, time_chars..-1//1) == crockford(rand)
        assert String.length(body) == String.length(plain_body)
      end
    end

    # Sabotage: the width check compares against rand_size + 1 -> every
    # matching rand raises ArgumentError and this test errors.
    test "with an explicit rand_size, and through generate/1 and generate!/1" do
      rand = bytes(4)
      opts = [time: @time, size: :m, rand_size: 4, rand: rand]

      assert {:ok, id} = UXID.generate(opts)
      assert UXID.generate!(opts) == id
      assert String.slice(id, 10..-1//1) == crockford(rand)
    end

    # Sabotage: the width check compares against max(rand_size, 1) -> an empty
    # rand under :xs raises ArgumentError and this test errors.
    test "rand: <<>> fits size :xs, which has no random field" do
      assert {:ok, %Codec{string: id, rand: <<>>}} = UXID.new(time: @time, size: :xs, rand: <<>>)
      assert String.length(id) == 10
    end

    # Sabotage: put_rand/2 drops the caller bytes for an upper-case call ->
    # the upper-case ID carries fresh random bytes and the comparison fails.
    test "the same time and rand always build the same ID, in either case" do
      opts = [prefix: "cus", time: @time, rand: bytes(10)]

      assert UXID.generate!(opts) == UXID.generate!(opts)

      assert UXID.generate!([case: :upper] ++ opts) ==
               "cus_" <> String.upcase(String.trim_leading(UXID.generate!(opts), "cus_"))
    end
  end

  describe "rand: width must match the random field" do
    # Sabotage: the width check never fires (byte_size(rand) < 0) -> a 9-byte
    # rand under xlarge encodes a shorter body and no ArgumentError is raised.
    test "too short raises ArgumentError" do
      assert_raise ArgumentError, ~r/must be exactly 10 bytes.*got: 9/, fn ->
        UXID.new(time: @time, rand: bytes(9))
      end

      assert_raise ArgumentError, ~r/must be exactly 0 bytes.*got: 1/, fn ->
        UXID.new(time: @time, size: :xs, rand: <<1>>)
      end
    end

    # Sabotage: the byte_size check changed from != to < -> an 11-byte rand
    # passes the check and no ArgumentError naming the width is raised.
    test "too long raises ArgumentError" do
      assert_raise ArgumentError, ~r/must be exactly 2 bytes.*got: 3/, fn ->
        UXID.new(time: @time, size: :small, rand: bytes(3))
      end

      assert_raise ArgumentError, ~r/must be exactly 10 bytes.*got: 11/, fn ->
        UXID.generate!(time: @time, rand: bytes(11))
      end
    end

    # Sabotage: the non-binary clause of put_rand/2 removed -> a FunctionClauseError
    # is raised instead of an ArgumentError.
    test "a non-binary rand raises ArgumentError" do
      assert_raise ArgumentError, ~r/must be a binary/, fn ->
        UXID.new(time: @time, rand: 42)
      end
    end
  end

  describe "rand: conflicts" do
    # Sabotage: the from: clause of put_rand/2 never matches -> the
    # deterministic path ignores rand and returns an ID.
    test "with from: raises ArgumentError" do
      assert_raise ArgumentError, ~r/rand: and from: are mutually exclusive/, fn ->
        UXID.new(prefix: "usr", from: "a@example.com", rand: bytes(10))
      end
    end

    # Sabotage: the monotonic branch of put_rand/2 never fires -> the caller's
    # bytes are used and no ArgumentError is raised.
    test "with monotonic: true raises ArgumentError" do
      assert_raise ArgumentError, ~r/cannot be used with monotonic generation/, fn ->
        UXID.new(time: @time, monotonic: true, rand: bytes(10))
      end
    end

    # Sabotage: the monotonic branch compares the raw option (monotonic == true)
    # instead of the resolved setting -> a size list matching the call passes.
    test "with a monotonic size list that contains the call's size raises ArgumentError" do
      assert_raise ArgumentError, ~r/cannot be used with monotonic generation/, fn ->
        UXID.new(time: @time, size: :small, monotonic: [:s], rand: bytes(2))
      end
    end

    # Sabotage: the monotonic branch raises for any non-false raw option -> a
    # size list that misses the call raises ArgumentError and this test errors.
    test "with a monotonic size list that does not contain the call's size is fine" do
      assert {:ok, %Codec{rand: <<1, 2>>}} =
               UXID.new(time: @time, size: :small, monotonic: [:medium], rand: <<1, 2>>)
    end
  end

  describe "calls without rand:" do
    # Sabotage: put_rand(codec, nil) fills the field with zero bytes -> two
    # calls build the same random field and the refute fails.
    test "rand: nil is the same as no option: fresh random bytes every call" do
      {:ok, %Codec{rand: a, string: id_a}} = UXID.new(time: @time, rand: nil)
      {:ok, %Codec{rand: b, string: id_b}} = UXID.new(time: @time)

      assert byte_size(a) == 10
      assert byte_size(b) == 10
      refute a == b
      assert String.length(id_a) == String.length(id_b)
    end
  end
end
