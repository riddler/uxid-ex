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

    test "threads the monotonic option through to generation" do
      opts = %{prefix: "evt", size: :small, monotonic: true, time: 1_700_000_800_000}

      # autogenerate/1 does not accept :time, so exercise monotonic via the same
      # per-process counter by pinning time through generate!/1's option instead.
      a = UXID.generate!(prefix: "evt", size: :small, monotonic: true, time: 1_700_000_800_000)
      b = UXID.generate!(prefix: "evt", size: :small, monotonic: true, time: 1_700_000_800_000)
      assert b > a

      # And confirm the Ecto entrypoint accepts and honors the field option.
      uxid = UXID.autogenerate(Map.delete(opts, :time))
      assert String.starts_with?(uxid, "evt_")
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

    test "without :validate, any binary passes through unchanged" do
      assert {:ok, "anything at all"} = UXID.cast("anything at all", %{prefix: "org"})
    end
  end

  describe "cast/2 in strict :validate mode" do
    @strict %{validate: true, prefix: "org"}

    test "accepts a well-formed UXID carrying the configured prefix" do
      uxid = UXID.generate!(prefix: "org")
      assert {:ok, ^uxid} = UXID.cast(uxid, @strict)
    end

    test "accepts a legacy bare UUID string (coexistence)" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, ^uuid} = UXID.cast(uuid, @strict)
    end

    test "accepts nil" do
      assert {:ok, nil} = UXID.cast(nil, @strict)
    end

    test "rejects a value carrying the wrong prefix" do
      wrong = UXID.generate!(prefix: "usr")
      assert :error = UXID.cast(wrong, @strict)
    end

    test "rejects malformed strings" do
      assert :error = UXID.cast("", @strict)
      assert :error = UXID.cast("org_", @strict)
      assert :error = UXID.cast("org_!!!bad", @strict)
      assert :error = UXID.cast("not-an-id", @strict)
    end

    test "rejects non-binary values" do
      assert :error = UXID.cast(123, @strict)
    end

    test "allow_uuid: false rejects legacy UUIDs" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert :error = UXID.cast(uuid, %{validate: true, prefix: "org", allow_uuid: false})
    end

    test "with :validate but no configured prefix, any well-formed UXID passes" do
      uxid = UXID.generate!(prefix: "anything")
      assert {:ok, ^uxid} = UXID.cast(uxid, %{validate: true})
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
