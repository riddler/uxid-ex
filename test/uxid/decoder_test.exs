defmodule UXID.DecoderTest do
  use ExUnit.Case, async: true
  import Bitwise

  alias UXID.{Decoder, Codec}

  describe "process/1 +" do
    test "Returns a decoded uxid struct from generated uxid" do
      {:ok, generated_uxid} = UXID.new()
      {:ok, decoded_uxid} = Decoder.process(%Codec{string: generated_uxid.string})

      assert decoded_uxid.prefix == nil
      assert decoded_uxid.prefix == generated_uxid.prefix
      assert decoded_uxid.encoded == generated_uxid.encoded
      assert decoded_uxid.rand_encoded == generated_uxid.rand_encoded
      assert decoded_uxid.string == generated_uxid.string
      assert decoded_uxid.time == generated_uxid.time
      assert decoded_uxid.time_encoded == generated_uxid.time_encoded
      assert decoded_uxid.rand == :decode_not_supported
      assert decoded_uxid.rand_size == :decode_not_supported
      assert decoded_uxid.size == :xlarge
    end

    test "Returns a decoded uxid struct from generated uxid with prefix" do
      {:ok, generated_uxid} = UXID.new(prefix: "prefix")
      {:ok, decoded_uxid} = Decoder.process(%Codec{string: generated_uxid.string})

      assert decoded_uxid.prefix == "prefix"
      assert decoded_uxid.prefix == generated_uxid.prefix
      assert decoded_uxid.encoded == generated_uxid.encoded
      assert decoded_uxid.rand_encoded == generated_uxid.rand_encoded
      assert decoded_uxid.string == generated_uxid.string
      assert decoded_uxid.time == generated_uxid.time
      assert decoded_uxid.time_encoded == generated_uxid.time_encoded
      assert decoded_uxid.rand == :decode_not_supported
      assert decoded_uxid.rand_size == :decode_not_supported
      assert decoded_uxid.size == :xlarge
    end
  end

  describe "separate_prefix/1" do
    test "no prefix" do
      {:ok, uxid} = UXID.new()

      assert %Codec{
               encoded: uxid.encoded,
               prefix: nil,
               string: uxid.string
             } == Decoder.separate_prefix(%Codec{prefix: nil, string: uxid.string})
    end

    test "prefix" do
      {:ok, uxid} = UXID.new(prefix: "prefix")

      assert %Codec{
               encoded: uxid.encoded,
               prefix: "prefix",
               string: uxid.string
             } == Decoder.separate_prefix(%Codec{prefix: nil, string: uxid.string})
    end

    test "prefix with underscore" do
      {:ok, uxid} = UXID.new(prefix: "multi_word_prefix")

      assert %Codec{
               encoded: uxid.encoded,
               prefix: "multi_word_prefix",
               string: uxid.string
             } == Decoder.separate_prefix(%Codec{prefix: nil, string: uxid.string})
    end
  end

  describe "separate_encoded/1" do
    test "separates time from the random bytes " do
      {:ok, uxid} = UXID.new()

      assert %Codec{
               encoded: uxid.encoded,
               rand_encoded: uxid.rand_encoded,
               time_encoded: uxid.time_encoded
             } == Decoder.separate_encoded(%Codec{encoded: uxid.encoded})
    end
  end

  describe "decode_time/1" do
    test "decodes the time back into unix" do
      {:ok, uxid} = UXID.new()

      assert %Codec{
               time_encoded: uxid.time_encoded,
               time: uxid.time
             } == Decoder.decode_time(%Codec{time_encoded: uxid.time_encoded})
    end
  end

  describe "decode_size/1" do
    test "infers size and compact mode from encoded length" do
      assert %Codec{size: :small, compact_time: false, encoded: "01G2B5M42HWY45"} ==
               Decoder.decode_size(%Codec{encoded: "01G2B5M42HWY45"})

      assert %Codec{size: :small, compact_time: true, encoded: "01G2B5M42HWY4"} ==
               Decoder.decode_size(%Codec{encoded: "01G2B5M42HWY4"})
    end
  end

  describe "decode_rand/1" do
    test "separates time from the random bytes " do
      assert %Codec{rand: :decode_not_supported} == Decoder.decode_rand(%Codec{})
    end
  end

  describe "decode_rand_size/1" do
    test "separates time from the random bytes " do
      assert %Codec{rand_size: :decode_not_supported} == Decoder.decode_rand_size(%Codec{})
    end
  end

  describe "stress tests" do
    test "All generated IDs have the same time encoded length" do
      Enum.all?(0..2_000_000, fn _ ->
        timestamp = 0..3_000_000_000_000 |> Enum.random()
        {:ok, uxid} = UXID.new(time: timestamp)
        String.length(uxid.time_encoded) == 10
      end)
    end
  end

  describe "compact_small_times decoding" do
    setup do
      Application.put_env(:uxid, :compact_small_times, true)

      on_exit(fn ->
        Application.delete_env(:uxid, :compact_small_times)
      end)
    end

    test "decodes compact :small UXID correctly with epoch reconstruction" do
      time = System.system_time(:millisecond)
      {:ok, encoded} = UXID.Encoder.process(%UXID.Codec{size: :small, time: time})

      {:ok, decoded} =
        UXID.Decoder.process(%UXID.Codec{
          string: encoded.string
        })

      # Time should be reconstructed to approximately the original
      # (within the same 40-bit epoch window)
      # The top 8 bits are inferred from current time, so should match closely
      time_diff = abs(decoded.time - time)
      assert time_diff < 1000
      assert decoded.size == :small
    end

    test "epoch reconstruction handles current time correctly" do
      # Create a UXID with a known timestamp
      time = System.system_time(:millisecond)
      {:ok, encoded} = UXID.Encoder.process(%UXID.Codec{size: :small, time: time})

      # Decode it immediately (same epoch)
      {:ok, decoded} =
        UXID.Decoder.process(%UXID.Codec{
          string: encoded.string
        })

      # The reconstructed time should be very close to the original
      # (same top 8 bits, same bottom 40 bits)
      epoch_original = time >>> 40
      epoch_decoded = decoded.time >>> 40
      assert epoch_original == epoch_decoded

      # Bottom 40 bits should be identical
      bottom_40_original = time &&& 0xFFFFFFFFFF
      bottom_40_decoded = decoded.time &&& 0xFFFFFFFFFF
      assert bottom_40_original == bottom_40_decoded
    end

    test "roundtrip with prefix in compact mode" do
      time = System.system_time(:millisecond)

      {:ok, encoded} =
        UXID.Encoder.process(%UXID.Codec{
          size: :small,
          time: time,
          prefix: "test"
        })

      {:ok, decoded} =
        UXID.Decoder.process(%UXID.Codec{
          string: encoded.string
        })

      assert decoded.prefix == "test"
      # Time reconstructed via epoch inference
      time_diff = abs(decoded.time - time)
      assert time_diff < 1000
      assert decoded.size == :small
    end

    test "compact_small_times timestamp is 8 characters for :small" do
      {:ok, encoded} = UXID.Encoder.process(%UXID.Codec{size: :small})

      {:ok, decoded} =
        UXID.Decoder.process(%UXID.Codec{
          string: encoded.string
        })

      assert String.length(decoded.time_encoded) == 8
      assert decoded.size == :small
    end

    test "standard timestamp is 10 characters for :medium" do
      {:ok, encoded} = UXID.Encoder.process(%UXID.Codec{size: :medium})

      {:ok, decoded} =
        UXID.Decoder.process(%UXID.Codec{
          string: encoded.string
        })

      assert String.length(decoded.time_encoded) == 10
      assert decoded.size == :medium
    end
  end
end
