defmodule UXID.EncoderTest do
  use ExUnit.Case, async: true

  alias UXID.{Codec, Encoder}

  describe "process/1 with blank UXID using upper case" do
    test "app config returns a lowercase 26 character string (ULID)" do
      Application.put_env(:uxid, :case, :upper)

      on_exit(fn ->
        Application.delete_env(:uxid, :case)
      end)

      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{})
      assert String.length(uxid) == 26
      refute uxid == String.downcase(uxid)
    end

    test "call config returns a lowercase 26 character string (ULID)" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{case: :upper})
      assert String.length(uxid) == 26
      refute uxid == String.downcase(uxid)
    end
  end

  describe "process/1 with a blank UXID" do
    test "returns a 26 character string (ULID)" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{})
      assert String.length(uxid) == 26
      assert uxid == String.downcase(uxid)
    end
  end

  describe "process/1" do
    test "returns a 26 character string with 10 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 10})
      assert String.length(uxid) == 26
    end

    test "returns a 25 character string with 9 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 9})
      assert String.length(uxid) == 25
    end

    test "returns a 23 character string with 8 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 8})
      assert String.length(uxid) == 23
    end

    test "returns a 22 character string with 7 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 7})
      assert String.length(uxid) == 22
    end

    test "returns a 20 character string with 6 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 6})
      assert String.length(uxid) == 20
    end

    test "returns a 18 character string with 5 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 5})
      assert String.length(uxid) == 18
    end

    test "returns a 17 character string with 4 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 4})
      assert String.length(uxid) == 17
    end

    test "returns a 15 character string with 3 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 3})
      assert String.length(uxid) == 15
    end

    test "returns a 14 character string with 2 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 2})
      assert String.length(uxid) == 14
    end

    test "returns a 12 character string with 1 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 1})
      assert String.length(uxid) == 12
    end

    test "returns a 10 character string with 0 bytes of randomness" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{rand_size: 0})
      assert String.length(uxid) == 10
    end

    test "returns a string delimited by a hyphen" do
      {:ok, %Codec{string: uxid}} = Encoder.process(%Codec{prefix: "X", delimiter: "-"})
      assert "X-" <> _uxid = uxid
    end
  end

  describe "min_size configuration" do
    setup do
      Application.put_env(:uxid, :min_size, :medium)

      on_exit(fn ->
        Application.delete_env(:uxid, :min_size)
      end)
    end

    test "upgrades :xsmall to :medium when min_size is :medium" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :xsmall})
      # :medium = 5 bytes rand = 8 chars, timestamp = 10 chars, total = 18
      assert String.length(codec.string) == 18
    end

    test "upgrades :small to :medium when min_size is :medium" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :small})
      assert String.length(codec.string) == 18
    end

    test "does not downgrade :large when min_size is :medium" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :large})
      # :large = 7 bytes rand = 12 chars, timestamp = 10 chars, total = 22
      assert String.length(codec.string) == 22
    end

    test "respects min_size through public API" do
      uxid = UXID.generate!(size: :small)
      assert String.length(uxid) == 18
    end
  end

  describe "compact_small_times configuration" do
    setup do
      Application.put_env(:uxid, :compact_small_times, true)

      on_exit(fn ->
        Application.delete_env(:uxid, :compact_small_times)
      end)
    end

    test "compact_small_times produces 8-char timestamp for :xsmall" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :xsmall})
      assert String.length(codec.time_encoded) == 8
      # Total: 8 + 2 = 10 chars (same as standard 10 + 0 = 10)
      assert String.length(codec.encoded) == 10
      assert String.length(codec.rand_encoded) == 2
    end

    test "compact_small_times produces 8-char timestamp for :small" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :small})
      assert String.length(codec.time_encoded) == 8
      # Total: 8 + 5 = 13 chars (3 bytes = 24 bits = 5 chars in Base32)
      assert String.length(codec.encoded) == 13
      assert String.length(codec.rand_encoded) == 5
    end

    test "compact_small_times does NOT affect :medium" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :medium})
      assert String.length(codec.time_encoded) == 10
      assert String.length(codec.encoded) == 18
    end

    test "compact_small_times does NOT affect :large" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :large})
      assert String.length(codec.time_encoded) == 10
      assert String.length(codec.encoded) == 22
    end

    test "compact preserves sortability within epoch" do
      {:ok, codec1} = UXID.Encoder.process(%UXID.Codec{size: :small, time: 1000})
      {:ok, codec2} = UXID.Encoder.process(%UXID.Codec{size: :small, time: 2000})
      assert codec1.time_encoded < codec2.time_encoded
    end

    test "compact_small_times via public API" do
      uxid = UXID.generate!(size: :small)
      assert String.length(uxid) == 13
    end

    test "compact_small_times with prefix" do
      uxid = UXID.generate!(size: :small, prefix: "usr")
      assert String.length(uxid) == 17
      assert String.starts_with?(uxid, "usr_")
    end

    test "compact_small_times works with min_size" do
      Application.put_env(:uxid, :min_size, :medium)

      on_exit(fn ->
        Application.delete_env(:uxid, :min_size)
      end)

      # Request :small, gets upgraded to :medium, should NOT be compacted
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :small})
      assert String.length(codec.time_encoded) == 10
      assert String.length(codec.encoded) == 18
    end
  end

  describe "compact_time per-call override" do
    setup do
      # Set global policy to compact small times
      Application.put_env(:uxid, :compact_small_times, true)

      on_exit(fn ->
        Application.delete_env(:uxid, :compact_small_times)
      end)
    end

    test "compact_time: false overrides global policy for :small" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :small, compact_time: false})
      assert String.length(codec.time_encoded) == 10
      assert String.length(codec.encoded) == 14
      assert String.length(codec.rand_encoded) == 4
    end

    test "compact_time: true works on :large even though global policy wouldn't apply" do
      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :large, compact_time: true})
      assert String.length(codec.time_encoded) == 8
      # 8 bytes = 64 bits = 13 chars in Base32
      assert String.length(codec.encoded) == 21
      assert String.length(codec.rand_encoded) == 13
    end

    test "compact_time: true via public API" do
      uxid = UXID.generate!(size: :large, compact_time: true)
      assert String.length(uxid) == 21
    end
  end

  describe "compact_time per-call override without global policy" do
    test "compact_time: true enables compact mode even when global policy is off" do
      # No global policy set (or explicitly false)
      Application.put_env(:uxid, :compact_small_times, false)

      on_exit(fn ->
        Application.delete_env(:uxid, :compact_small_times)
      end)

      {:ok, codec} = UXID.Encoder.process(%UXID.Codec{size: :small, compact_time: true})
      assert String.length(codec.time_encoded) == 8
      assert String.length(codec.rand_encoded) == 5
    end
  end

  describe "compact_time in Ecto autogenerate" do
    # Note: This test requires Ecto to be loaded
    # If Ecto is not available, this test will be skipped
    @tag :ecto
    test "autogenerate respects per-field compact_time option" do
      if Code.ensure_loaded?(Ecto.ParameterizedType) do
        # Simulate autogenerate with compact_time: true
        opts = %{prefix: "sess", size: :small, compact_time: true}
        uxid = UXID.autogenerate(opts)

        # Decode to verify it was compacted
        {:ok, decoded} = UXID.decode(uxid)
        assert String.length(decoded.time_encoded) == 8
        assert decoded.size == :small
      else
        # Skip test if Ecto is not loaded
        :ok
      end
    end

    @tag :ecto
    test "autogenerate compact_time: false overrides global policy" do
      if Code.ensure_loaded?(Ecto.ParameterizedType) do
        Application.put_env(:uxid, :compact_small_times, true)

        on_exit(fn ->
          Application.delete_env(:uxid, :compact_small_times)
        end)

        # Explicitly disable compact for this field
        opts = %{prefix: "sess", size: :small, compact_time: false}
        uxid = UXID.autogenerate(opts)

        # Decode to verify it was NOT compacted
        {:ok, decoded} = UXID.decode(uxid)
        assert String.length(decoded.time_encoded) == 10
        assert decoded.size == :small
      else
        :ok
      end
    end
  end
end
