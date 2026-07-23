defmodule UXID.DeterministicTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias UXID.{Codec, Decoder}

  # Body length per size for deterministic IDs (1 marker char + hash chars).
  # Mirrors the canonical table in design/deterministic-uxid.md.
  @body_length %{
    xs: 10,
    xsmall: 10,
    s: 14,
    small: 14,
    m: 18,
    medium: 18,
    l: 22,
    large: 22,
    xl: 26,
    xlarge: 26
  }

  describe "determinism" do
    test "same {from, prefix, size, case} yields identical strings across many runs" do
      ids =
        for _ <- 1..50 do
          UXID.generate!(prefix: "usr", from: "alice@example.com", size: :medium)
        end

      assert Enum.uniq(ids) == [List.first(ids)]
    end

    test "is independent of the process it runs in" do
      here = UXID.generate!(prefix: "usr", from: "alice@example.com")

      there =
        Task.async(fn -> UXID.generate!(prefix: "usr", from: "alice@example.com") end)
        |> Task.await()

      assert here == there
    end

    test "generate/1 and new/1 agree with generate!/1" do
      opts = [prefix: "usr", from: "alice@example.com"]

      assert {:ok, string} = UXID.generate(opts)
      assert {:ok, %Codec{string: ^string}} = UXID.new(opts)
      assert UXID.generate!(opts) == string
    end
  end

  describe "prefix as namespace" do
    test "same string under different prefixes yields different bodies" do
      a = UXID.generate!(prefix: "usr", from: "alice@example.com")
      b = UXID.generate!(prefix: "org", from: "alice@example.com")

      assert body(a) != body(b)
    end

    test "no prefix (global scope) works and differs from a prefixed body" do
      global = UXID.generate!(from: "alice@example.com")
      scoped = UXID.generate!(prefix: "usr", from: "alice@example.com")

      refute String.contains?(global, "_")
      assert String.starts_with?(global, "z")
      assert body(global) != body(scoped)
    end
  end

  describe "size" do
    test "each size yields the canonical body length" do
      for {size, length} <- @body_length do
        id = UXID.generate!(prefix: "usr", from: "alice@example.com", size: size)
        assert String.length(body(id)) == length, "size #{size} produced #{body(id)}"
      end
    end

    test "unset size defaults to the xlarge length" do
      id = UXID.generate!(prefix: "usr", from: "alice@example.com")
      assert String.length(body(id)) == 26
    end

    test "same string at two sizes yields unrelated bodies, not a shared prefix" do
      small = body(UXID.generate!(prefix: "cus", from: "acme-corp", size: :small))
      medium = body(UXID.generate!(prefix: "cus", from: "acme-corp", size: :medium))

      refute String.starts_with?(medium, small)
    end
  end

  describe "case" do
    test "upper and lower are the same ID in different case" do
      lower = UXID.generate!(prefix: "usr", from: "x", case: :lower)
      upper = UXID.generate!(prefix: "usr", from: "x", case: :upper)

      # Case is a display concern applied to the body only; the prefix is
      # untouched, so the two bodies are the same ID in different case.
      assert String.upcase(body(lower)) == body(upper)
    end

    test "the marker follows the case" do
      assert String.starts_with?(
               body(UXID.generate!(prefix: "usr", from: "x", case: :lower)),
               "z"
             )

      assert String.starts_with?(
               body(UXID.generate!(prefix: "usr", from: "x", case: :upper)),
               "Z"
             )
    end
  end

  describe "marker and sorting" do
    test "the body starts with the z/Z marker" do
      assert String.starts_with?(body(UXID.generate!(prefix: "usr", from: "x")), "z")
    end

    test "a deterministic ID sorts after a time-based ID of the same prefix" do
      time_id = UXID.generate!(prefix: "usr", size: :medium)
      det_id = UXID.generate!(prefix: "usr", from: "x", size: :medium)

      assert body(det_id) > body(time_id)
    end
  end

  describe "round-trip decode" do
    test "decode reports deterministic: true, time: nil, and the right size" do
      for {size, _length} <- @body_length do
        id = UXID.generate!(prefix: "usr", from: "alice@example.com", size: size)
        {:ok, decoded} = UXID.decode(id)

        assert decoded.deterministic == true
        assert decoded.time == nil
        assert decoded.size == canonical_size(size)
      end
    end

    test "a time-based ID decodes as deterministic: false with a real time" do
      {:ok, decoded} = UXID.decode(UXID.generate!(prefix: "cus", size: :medium))

      assert decoded.deterministic == false
      assert is_integer(decoded.time)
    end

    test "deterministic?/1 and valid?/2 agree" do
      det = UXID.generate!(prefix: "usr", from: "x")
      time = UXID.generate!(prefix: "usr")

      assert UXID.deterministic?(det)
      refute UXID.deterministic?(time)
      assert UXID.valid?(det)
    end
  end

  describe "conflicts" do
    test "from: with explicit monotonic: true raises" do
      assert_raise ArgumentError, ~r/mutually exclusive/, fn ->
        UXID.generate!(prefix: "usr", from: "x", monotonic: true)
      end
    end

    test "a non-binary from: raises" do
      assert_raise ArgumentError, ~r/must be a string/, fn ->
        UXID.generate!(prefix: "usr", from: 123)
      end
    end
  end

  describe "compact first-char cap" do
    # t1 (top 5 bits of the 40-bit compact time) == 31 is reserved as the
    # deterministic marker, so a compact timestamp in that band must raise.
    @reserved 31 <<< 35

    test "a reserved-band timestamp raises" do
      assert_raise ArgumentError, ~r/reserved/, fn ->
        UXID.generate!(size: :small, compact_time: true, time: @reserved)
      end
    end

    test "the timestamp just below the reserved band still encodes" do
      id = UXID.generate!(size: :small, compact_time: true, time: @reserved - 1)
      # value 30 -> 'y'
      assert String.starts_with?(id, "y")
    end

    test "a normal now-based compact ID is unaffected" do
      id = UXID.generate!(size: :small, compact_time: true)
      refute String.starts_with?(id, "z")
    end
  end

  describe "golden vectors (wire-format lock)" do
    test "known {prefix, from, size} map to exact strings" do
      assert UXID.generate!(prefix: "usr", from: "alice@example.com") ==
               "usr_zcvt7epac0t1ebcsjfyf7cwz25"

      assert UXID.generate!(prefix: "cus", from: "acme-corp", size: :small) ==
               "cus_zt9vnyfd85bff0"

      assert UXID.generate!(from: "alice@example.com", size: :medium) ==
               "zqz4cwzgyw8ks97869"
    end
  end

  # The encoded body, with any prefix + delimiter stripped.
  defp body(uxid) do
    {:ok, %Codec{encoded: encoded}} = Decoder.process(%Codec{string: uxid})
    encoded
  end

  defp canonical_size(:xs), do: :xsmall
  defp canonical_size(:s), do: :small
  defp canonical_size(:m), do: :medium
  defp canonical_size(:l), do: :large
  defp canonical_size(:xl), do: :xlarge
  defp canonical_size(size), do: size
end
