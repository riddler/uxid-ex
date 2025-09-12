defmodule UXID.DecoderTest do
  use ExUnit.Case, async: true

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
      assert decoded_uxid.size == :decode_not_supported
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
      assert decoded_uxid.size == :decode_not_supported
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
    test "separates time from the random bytes " do
      assert %Codec{size: :decode_not_supported} == Decoder.decode_size(%Codec{})
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
end
