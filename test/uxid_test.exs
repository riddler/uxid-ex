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
  end
end
