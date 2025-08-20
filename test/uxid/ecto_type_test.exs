defmodule UXID.EctoTypeTest do
  use ExUnit.Case, async: true

  describe "autogenerate/1" do
    test "generates a UXID with specified options" do
      opts = %{prefix: "px", size: 10, rand_size: 5}
      uxid = UXID.EctoType.autogenerate(opts)

      assert String.starts_with?(uxid, "px")
    end

    test "generates a UXID with case parameter" do
      opts = %{prefix: "px", case: :upper}
      uxid = UXID.EctoType.autogenerate(opts)

      assert String.starts_with?(uxid, "px_")
      # Extract the encoded part after prefix and underscore
      encoded_part = String.replace_leading(uxid, "px_", "")
      # Should contain uppercase letters (not lowercase)
      assert encoded_part =~ ~r/[A-Z]/
      refute encoded_part =~ ~r/[a-z]/
    end

    test "generates a UXID with lowercase case parameter" do
      opts = %{prefix: "px", case: :lower}
      uxid = UXID.EctoType.autogenerate(opts)

      assert String.starts_with?(uxid, "px_")
      # Extract the encoded part after prefix and underscore
      encoded_part = String.replace_leading(uxid, "px_", "")
      # Should contain lowercase letters (not uppercase)
      assert encoded_part =~ ~r/[a-z]/
      refute encoded_part =~ ~r/[A-Z]/
    end

    test "defaults to configured case when not specified" do
      opts = %{prefix: "px"}
      uxid = UXID.EctoType.autogenerate(opts)

      assert String.starts_with?(uxid, "px_")
      # Should use the default case (lowercase in v2.0+)
      encoded_part = String.replace_leading(uxid, "px_", "")
      assert encoded_part =~ ~r/[a-z]/
    end
  end

  describe "cast/2" do
    test "casts binary data correctly" do
      {:ok, result} = UXID.EctoType.cast("some_data", %{})
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
      assert UXID.EctoType.type(%{}) == :string
    end
  end

  describe "init/1" do
    test "initializes options correctly" do
      opts = [prefix: "px", size: 10, rand_size: 5]
      expected_opts = %{prefix: "px", size: 10, rand_size: 5}
      assert UXID.EctoType.init(opts) == expected_opts
    end
  end

  describe "load/3" do
    test "loads data correctly" do
      {:ok, result} = UXID.EctoType.load("some_data", nil, nil)
      assert result == "some_data"
    end
  end

  describe "dump/3" do
    test "dumps data correctly" do
      {:ok, result} = UXID.EctoType.dump("some_data", nil, nil)
      assert result == "some_data"
    end
  end
end
