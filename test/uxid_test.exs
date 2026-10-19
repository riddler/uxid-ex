defmodule UXIDTest do
  use ExUnit.Case, async: true
  doctest UXID

  describe "generate/0" do
    test "returns a 26 character string (ULID)" do
      {:ok, uxid} = UXID.generate()
      assert String.length(uxid) == 26
    end
  end

  describe "generate/1" do
    test "returns a 26 character string with 10 bytes of randomness" do
      {:ok, uxid} = UXID.generate(rand_bytes: 10)
      assert String.length(uxid) == 26
    end

    test "generated IDs are binaries" do
      {:ok, uxid} = UXID.generate(prefix: "binary")
      assert is_binary(uxid)
    end
  end

  describe "new/1" do
    test "Returns a UXID struct" do
      assert {:ok, %UXID.Codec{}} = UXID.new()
    end
  end

  describe "decode/1" do
    test "hardcoded uxid" do
      {:ok, decoded_uxid} = UXID.decode("01G2B5M42HWY45WE5YQE3P2CJ2")

      assert %UXID.Codec{
               deterministic: false,
               encoded: "01G2B5M42HWY45WE5YQE3P2CJ2",
               from: nil,
               prefix: nil,
               rand: :decode_not_supported,
               rand_encoded: "WY45WE5YQE3P2CJ2",
               rand_size: :decode_not_supported,
               size: :xlarge,
               compact_time: false,
               string: "01G2B5M42HWY45WE5YQE3P2CJ2",
               time: 1_651_789_926_481,
               time_encoded: "01G2B5M42H"
             } == decoded_uxid
    end
  end

  describe "cast/2" do
    test "casting this thing" do
      assert {:ok, _} = UXID.cast(UXID.generate!(), %{})
      assert {:ok, _} = UXID.cast(UXID.generate!(prefix: "pre"), %{})
      assert :error = UXID.cast(1, %{})
      assert :error = UXID.cast(:atom, %{})
    end
  end

  describe "valid?/2" do
    test "accepts generated UXIDs, with and without a prefix" do
      assert UXID.valid?(UXID.generate!())
      assert UXID.valid?(UXID.generate!(prefix: "cus"))
      assert UXID.valid?(UXID.generate!(prefix: "cus"), prefix: "cus")
    end

    test "enforces a required prefix" do
      refute UXID.valid?(UXID.generate!(prefix: "cus"), prefix: "usr")
      refute UXID.valid?(UXID.generate!(), prefix: "usr")
    end

    test "rejects non-Crockford, too-short, and non-binary values" do
      refute UXID.valid?("")
      refute UXID.valid?("short")
      refute UXID.valid?("cus_!!!")
      refute UXID.valid?(nil)
      refute UXID.valid?(123)
    end

    test "does not treat a bare UUID as a valid UXID" do
      refute UXID.valid?("550e8400-e29b-41d4-a716-446655440000")
    end

    test "honors a custom delimiter" do
      id = UXID.generate!(prefix: "cus", delimiter: "-")
      assert UXID.valid?(id, prefix: "cus", delimiter: "-")
    end
  end

  # An empty prefix and an absent prefix are the same input: no prefix. Every
  # entry point that takes `:prefix` answers for "" what it answers for nil.
  describe "empty prefix" do
    @time 1_700_000_900_000
    @bare "01emdgjf0dqxqj8fm78xe97y3h"

    # Sabotage: read `:prefix` raw in UXID.new/1 - the id gains a leading delimiter.
    test "the time path emits the bare body" do
      id = UXID.generate!(prefix: "", time: @time)

      refute String.starts_with?(id, "_")
      assert String.length(id) == String.length(UXID.generate!(time: @time))
    end

    # Sabotage: read `:prefix` raw in UXID.new/1 - the compact id gains a leading delimiter.
    test "the compact path emits the bare body" do
      id = UXID.generate!(prefix: "", size: :small, compact_time: true, time: @time)
      bare = UXID.generate!(size: :small, compact_time: true, time: @time)

      refute String.starts_with?(id, "_")
      assert String.length(id) == String.length(bare)
    end

    # Sabotage: read `:prefix` raw in UXID.new/1 - same hash, but a leading delimiter.
    test "the deterministic path matches an absent prefix exactly" do
      assert UXID.generate!(prefix: "", from: "alice@example.com") ==
               UXID.generate!(from: "alice@example.com")
    end

    # Sabotage: read `:prefix` raw in UXID.new/1 - "" and nil key two separate counters.
    test "the monotonic counter is shared with an absent prefix" do
      UXID.Monotonic.reset(nil, 10)
      UXID.Monotonic.reset("", 10)

      bodies =
        for i <- 1..20 do
          prefix = if rem(i, 2) == 0, do: "", else: nil
          UXID.generate!(prefix: prefix, monotonic: true, time: @time)
        end
        |> Enum.map(&(&1 |> String.split("_") |> List.last()))

      assert bodies == Enum.sort(bodies)
      assert bodies == Enum.uniq(bodies)
    end

    # Sabotage: read `:prefix` raw in UXID.valid?/2 - a bare body then fails `prefix: ""`.
    test "valid?/2 reads an empty prefix as no prefix" do
      for id <- [@bare, "_" <> @bare, "cus_" <> @bare] do
        assert UXID.valid?(id, prefix: "") == UXID.valid?(id), "differed for #{id}"
      end

      assert UXID.valid?(@bare, prefix: "")
      assert UXID.valid?("cus_" <> @bare, prefix: "")
    end

    # Sabotage: check the raw `:prefix` option via prefix_ok?/2 in UXID.deterministic?/2.
    test "deterministic?/2 reads an empty prefix as no prefix" do
      det = UXID.generate!(from: "alice@example.com")

      for id <- [det, @bare, "usr_" <> det] do
        assert UXID.deterministic?(id, prefix: "") == UXID.deterministic?(id),
               "differed for #{id}"
      end

      assert UXID.deterministic?(det, prefix: "")
    end

    # Sabotage: read `:prefix` raw in UXID.new/1 and UXID.valid?/2 (Ecto entry points).
    test "the Ecto type's prefix option reads an empty prefix as no prefix" do
      refute String.starts_with?(UXID.autogenerate(%{prefix: ""}), "_")

      assert {:ok, @bare} = UXID.cast(@bare, %{validate: true, prefix: ""})

      assert UXID.cast("cus_" <> @bare, %{validate: true, prefix: ""}) ==
               UXID.cast("cus_" <> @bare, %{validate: true})
    end
  end
end
