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
               encoded: "01G2B5M42HWY45WE5YQE3P2CJ2",
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
end
