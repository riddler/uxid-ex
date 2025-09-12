defmodule UXID.EctoTypeTest do
  use ExUnit.Case, async: true

  describe "autogenerate/1" do
    test "generates a UXID with specified options" do
      opts = %{prefix: "px", size: 10, rand_size: 5}
      uxid = UXID.autogenerate(opts)

      assert String.starts_with?(uxid, "px")
    end

    test "generates a UXID with case and delimiter options" do
      opts = %{prefix: "test", case: :upper, delimiter: "-"}
      uxid = UXID.autogenerate(opts)

      assert String.starts_with?(uxid, "test-")
      # Check that the UXID portion after prefix is uppercase
      [_prefix, uxid_part] = String.split(uxid, "-", parts: 2)
      refute uxid_part == String.downcase(uxid_part)
    end
  end

  describe "cast/2" do
    test "casts binary data correctly" do
      {:ok, result} = UXID.cast("some_data", %{})
      assert result == "some_data"

      assert {:ok, _} = UXID.cast(UXID.generate!(), %{})
      assert {:ok, result3} = UXID.cast(UXID.generate!(prefix: "pre"), %{})
      assert String.starts_with?(result3, "pre")
    end

    test "returns error on invalid data" do
      assert :error = UXID.cast(1, %{})
      assert :error = UXID.cast(:atom, %{})
    end
  end

  describe "type/1" do
    test "returns the underlying schema type for a UXID" do
      assert UXID.type(%{}) == :string
    end
  end

  describe "init/1" do
    test "initializes options correctly" do
      opts = [prefix: "px", size: 10, rand_size: 5]
      expected_opts = %{prefix: "px", size: 10, rand_size: 5}
      assert UXID.init(opts) == expected_opts
    end
  end

  describe "load/3" do
    test "loads data correctly" do
      {:ok, result} = UXID.load("some_data", nil, nil)
      assert result == "some_data"
    end
  end

  describe "dump/3" do
    test "dumps data correctly" do
      {:ok, result} = UXID.dump("some_data", nil, nil)
      assert result == "some_data"
    end
  end
end
