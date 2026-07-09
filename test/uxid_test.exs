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
end
