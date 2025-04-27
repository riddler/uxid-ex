defmodule UXID.EncoderTest do
  use ExUnit.Case, async: true

  alias UXID.Encoder

  describe "process/1 with blank UXID using lowercase" do
    test "app config returns a lowercase 26 character string (ULID)" do
      Application.put_env(:uxid, :case, :lower)
      on_exit fn ->
        Application.delete_env(:uxid, :case)
      end

      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{})
      assert String.length(uxid) == 26
      assert uxid == String.downcase(uxid)
    end

    test "call config returns a lowercase 26 character string (ULID)" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{case: :lower})
      assert String.length(uxid) == 26
      assert uxid == String.downcase(uxid)
    end
  end

  describe "process/1 with a blank UXID" do
    test "returns a 26 character string (ULID)" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{})
      assert String.length(uxid) == 26
    end
  end

  describe "process/1" do
    test "returns a 26 character string with 10 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 10})
      assert String.length(uxid) == 26
    end

    test "returns a 25 character string with 9 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 9})
      assert String.length(uxid) == 25
    end

    test "returns a 23 character string with 8 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 8})
      assert String.length(uxid) == 23
    end

    test "returns a 22 character string with 7 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 7})
      assert String.length(uxid) == 22
    end

    test "returns a 20 character string with 6 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 6})
      assert String.length(uxid) == 20
    end

    test "returns a 18 character string with 5 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 5})
      assert String.length(uxid) == 18
    end

    test "returns a 17 character string with 4 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 4})
      assert String.length(uxid) == 17
    end

    test "returns a 15 character string with 3 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 3})
      assert String.length(uxid) == 15
    end

    test "returns a 14 character string with 2 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 2})
      assert String.length(uxid) == 14
    end

    test "returns a 12 character string with 1 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 1})
      assert String.length(uxid) == 12
    end

    test "returns a 10 character string with 0 bytes of randomness" do
      {:ok, %UXID{string: uxid}} = Encoder.process(%UXID{rand_size: 0})
      assert String.length(uxid) == 10
    end
  end
end
