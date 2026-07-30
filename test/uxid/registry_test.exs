# A registry-level default in the list form of :monotonic, for the manifest's
# only non-scalar field.
defmodule UXID.RegistryTest.ListMonotonicIDs do
  @moduledoc false
  use UXID.Registry, default_monotonic: [:small, :medium]

  defid :note, prefix: "note", size: :small
end

defmodule UXID.RegistryTest do
  use ExUnit.Case, async: true

  doctest UXID.Registry

  alias UXID.RegistryTest.ListMonotonicIDs
  alias UXID.TestSupport.{Contact, DeterministicIDs, Event, IDs, Org}

  describe "by-key API" do
    test "prefix/1, size/1, schema/1, category/1" do
      assert IDs.prefix(:org) == "org"
      assert IDs.size(:org) == :medium
      assert IDs.schema(:org) == Org
      assert IDs.category(:org) == :account
    end

    test "size falls back to default_size" do
      assert IDs.size(:lead) == :medium
    end

    test "schema/category default to nil" do
      assert IDs.schema(:lead) == nil
      assert IDs.category(:lead) == nil
    end

    test "fetch! raises on an unknown key" do
      assert_raise ArgumentError, ~r/not a registered UXID key/, fn -> IDs.prefix(:nope) end
    end

    test "entry/1 returns nil for an unknown key" do
      assert IDs.entry(:nope) == nil
    end

    test "field_opts/1 carries prefix, size, validate, allow_uuid, delimiter" do
      assert IDs.field_opts(:org) == [
               prefix: "org",
               size: :medium,
               validate: true,
               allow_uuid: true,
               delimiter: "_"
             ]

      assert Keyword.get(IDs.field_opts(:contact), :allow_uuid) == false
    end

    test "field_opts/1 carries the shape options a key declares" do
      opts = IDs.field_opts(:event)

      assert Keyword.get(opts, :monotonic) == true
      assert Keyword.get(opts, :compact_time) == true
      assert Keyword.get(IDs.field_opts(:ticket), :rand_size) == 4
    end

    test "field_opts/1 omits shape options a key leaves unset" do
      opts = IDs.field_opts(:org)

      refute Keyword.has_key?(opts, :monotonic)
      refute Keyword.has_key?(opts, :compact_time)
      refute Keyword.has_key?(opts, :rand_size)
    end

    test "monotonic/1 reads the key's declaration" do
      assert IDs.monotonic(:event) == true
      assert IDs.monotonic(:org) == nil
    end

    test "all/0 lists entries in declaration order" do
      assert Enum.map(IDs.all(), & &1.key) == [:org, :contact, :lead, :in_ref, :event, :ticket]
    end

    test "keys/0 and reserved/0" do
      assert IDs.keys() == [:org, :contact, :lead, :in_ref, :event, :ticket]
      assert IDs.reserved() == ["usr"]
    end

    test "generate!/1 mints an ID with the registered prefix" do
      id = IDs.generate!(:org)
      assert String.starts_with?(id, "org_")
      assert IDs.key_for(id) == :org
    end

    test "generate/1 returns an ok tuple" do
      assert {:ok, id} = IDs.generate(:contact)
      assert String.starts_with?(id, "contact_")
    end
  end

  describe "JSON manifest" do
    test "manifest/0 is JSON-safe data with string keys and scalar values" do
      assert %{"key" => "org", "prefix" => "org", "size" => "medium", "category" => "account"} =
               Enum.find(IDs.manifest(), &(&1["key"] == "org"))
    end

    test "manifest/0 renders unset size/category as nil" do
      lead = Enum.find(IDs.manifest(), &(&1["key"] == "lead"))

      assert lead == %{
               "key" => "lead",
               "prefix" => "lead",
               "size" => "medium",
               "category" => nil,
               "deterministic" => false,
               "monotonic" => nil,
               "compact_time" => nil,
               "rand_size" => nil
             }
    end

    test "manifest/0 carries the shape options another generator must reproduce" do
      event = Enum.find(IDs.manifest(), &(&1["key"] == "event"))
      ticket = Enum.find(IDs.manifest(), &(&1["key"] == "ticket"))

      assert event["monotonic"] == true
      assert event["compact_time"] == true
      assert ticket["rand_size"] == 4
    end

    test "manifest_json/0 emits deterministic JSON with nulls" do
      json = IDs.manifest_json()

      assert String.starts_with?(json, "[")
      assert String.ends_with?(json, "]")

      assert json =~
               ~s({"key":"org","prefix":"org","size":"medium","category":"account","deterministic":false,"monotonic":null,"compact_time":null,"rand_size":null})

      assert json =~
               ~s({"key":"lead","prefix":"lead","size":"medium","category":null,"deterministic":false,"monotonic":null,"compact_time":null,"rand_size":null})
    end

    test "manifest_json/0 emits shape options as unquoted scalars" do
      json = IDs.manifest_json()

      assert json =~ ~s("monotonic":true,"compact_time":true)
      assert json =~ ~s("rand_size":4)
    end

    test "manifest/0 renders a list-form monotonic as a JSON array of sizes" do
      assert [%{"monotonic" => ["small", "medium"]}] = ListMonotonicIDs.manifest()
      assert ListMonotonicIDs.manifest_json() =~ ~s("monotonic":["small","medium"])
    end

    test "manifest/0 carries the deterministic flag as a real boolean" do
      export = Enum.find(DeterministicIDs.manifest(), &(&1["key"] == "export"))
      assert export["deterministic"] == true
    end

    test "manifest_json/0 emits deterministic as an unquoted JSON bool" do
      json = DeterministicIDs.manifest_json()

      assert json =~ ~s("deterministic":true)
      refute json =~ ~s("deterministic":"true")
    end
  end

  describe "by-ID-string routing" do
    test "known?/1 is a cheap prefix membership check" do
      assert IDs.known?("org_01h2xssfw0000000000000000")
      refute IDs.known?("nope_01h2xssfw0000000000000000")
      refute IDs.known?("bare01h2xssfw0")
      refute IDs.known?(:not_a_binary)
    end

    test "resolve/1, key_for/1, schema_for/1" do
      id = "contact_01h2xssfw0000000000000000"
      assert %{key: :contact, schema: Contact} = IDs.resolve(id)
      assert IDs.key_for(id) == :contact
      assert IDs.schema_for(id) == Contact
    end

    test "unregistered prefixes resolve to nil" do
      assert IDs.resolve("nope_01h2xssfw0000000000000000") == nil
      assert IDs.key_for("nope_01h2xssfw0000000000000000") == nil
      assert IDs.schema_for("nope_01h2xssfw0000000000000000") == nil
    end

    test "compound underscore prefixes round-trip via split-on-last-delimiter" do
      id = IDs.generate!(:in_ref)
      assert String.starts_with?(id, "in_ref_")
      assert IDs.key_for(id) == :in_ref
    end
  end

  describe "split_last/2" do
    test "splits on the last delimiter" do
      assert UXID.Registry.split_last("in_ref_01h2x", "_") == {"in_ref", "01h2x"}
    end

    test "returns nil prefix when the delimiter is absent" do
      assert UXID.Registry.split_last("01h2x", "_") == {nil, "01h2x"}
    end
  end

  describe "compile-time validation" do
    test "rejects a malformed prefix" do
      assert_raise ArgumentError, ~r/does not match/, fn ->
        Code.compile_string("""
        defmodule Sample.BadFormat do
          use UXID.Registry
          defid :bad, prefix: "NOPE!"
        end
        """)
      end
    end

    test "rejects duplicate prefixes (including retired)" do
      assert_raise ArgumentError, ~r/duplicate UXID prefixes/, fn ->
        Code.compile_string("""
        defmodule Sample.DupPrefix do
          use UXID.Registry
          defid :a, prefix: "dup"
          retired "dup"
        end
        """)
      end
    end

    test "rejects duplicate keys" do
      assert_raise ArgumentError, ~r/duplicate UXID keys/, fn ->
        Code.compile_string("""
        defmodule Sample.DupKey do
          use UXID.Registry
          defid :a, prefix: "aa"
          defid :a, prefix: "bb"
        end
        """)
      end
    end

    test "rejects a missing prefix" do
      assert_raise ArgumentError, ~r/requires a string :prefix/, fn ->
        Code.compile_string("""
        defmodule Sample.NoPrefix do
          use UXID.Registry
          defid :a
        end
        """)
      end
    end

    test "rejects a delimiter that can appear in a Base32 body" do
      assert_raise ArgumentError, ~r/single character that cannot appear/, fn ->
        Code.compile_string("""
        defmodule Sample.BadDelimiter do
          use UXID.Registry, delimiter: "a"
          defid :a, prefix: "aa"
        end
        """)
      end
    end

    test "rejects a malformed shape option" do
      bad = [
        {"monotonic: :yes", "defid :a, prefix: \"aa\", monotonic: :yes"},
        {"monotonic list", "defid :a, prefix: \"aa\", monotonic: [:small, :tiny]"},
        {"compact_time", "defid :a, prefix: \"aa\", compact_time: :yes"},
        {"rand_size", "defid :a, prefix: \"aa\", rand_size: -1"},
        {"size", "defid :a, prefix: \"aa\", size: :tiny"}
      ]

      for {label, defid} <- bad do
        assert_raise ArgumentError, ~r/invalid .* for defid :a/, fn ->
          Code.compile_string("""
          defmodule Sample.BadShape#{:erlang.phash2(label)} do
            use UXID.Registry
            #{defid}
          end
          """)
        end
      end
    end

    test "rejects a bad registry-level default" do
      assert_raise ArgumentError, ~r/invalid :size for defid :a/, fn ->
        Code.compile_string("""
        defmodule Sample.BadDefaultSize do
          use UXID.Registry, default_size: :tiny
          defid :a, prefix: "aa"
        end
        """)
      end
    end

    test "rejects a key that is both deterministic and monotonic" do
      assert_raise ArgumentError,
                   ~r/declares both\s+deterministic: true and monotonic: true/,
                   fn ->
                     Code.compile_string("""
                     defmodule Sample.DetMono do
                       use UXID.Registry
                       defid :a, prefix: "aa", deterministic: true, monotonic: true
                     end
                     """)
                   end
    end

    test "rejects an unrecognized defid option" do
      assert_raise ArgumentError, ~r/unrecognized defid option\(s\) for :a.*\[:validat\]/s, fn ->
        Code.compile_string("""
        defmodule Sample.TypoOpt do
          use UXID.Registry
          defid :a, prefix: "aa", validat: false
        end
        """)
      end
    end
  end

  describe "generate!/2 opts passthrough" do
    test "merges caller opts over the registry's" do
      assert {:ok, "org_" <> body} = IDs.generate(:org, case: :upper)
      assert String.upcase(body) == body
    end

    test "arity-1 calls are unchanged" do
      assert String.starts_with?(IDs.generate!(:org), "org_")
    end

    test "from: mints a deterministic id by key" do
      id = IDs.generate!(:org, from: "+15555550123")

      assert id == IDs.generate!(:org, from: "+15555550123")
      assert UXID.deterministic?(id)
      assert String.starts_with?(id, "org_")
    end

    test "a deterministic by-key id carries the registry's prefix and size" do
      id = IDs.generate!(:in_ref, from: "abc")

      assert {:ok, decoded} = UXID.decode(id)
      assert decoded.prefix == "in_ref"
      assert decoded.size == :small
    end

    test "rejects an override of prefix or size" do
      for opt <- [[prefix: "nope"], [size: :large]] do
        assert_raise ArgumentError, ~r/cannot be overridden when generating by key/, fn ->
          IDs.generate!(:org, opt)
        end
      end
    end

    test "a monotonic key mints strictly increasing ids within a millisecond" do
      ids = for _ <- 1..25, do: IDs.generate!(:event)

      assert ids == Enum.sort(ids)
      assert Enum.uniq(ids) == ids
    end

    test "a call site can still opt a monotonic key out" do
      # Same shape, but drawn from the CSPRNG rather than the per-prefix counter.
      id = IDs.generate!(:event, monotonic: false)

      assert String.starts_with?(id, "evt_")
      assert String.length(id) == String.length(IDs.generate!(:event))
    end

    test "a key's rand_size widens the body" do
      # :ticket pins 4 random bytes (7 chars) against the default :xl 10 (16).
      assert String.length(IDs.generate!(:ticket)) ==
               String.length("tkt_") + 10 + 7
    end

    test "the pinned-opt check also guards generate/2" do
      assert_raise ArgumentError, ~r/cannot be overridden/, fn ->
        IDs.generate(:org, prefix: "nope")
      end
    end
  end

  describe "shape options through an Ecto field" do
    test "autogenerate mints the shape the key declares" do
      {:parameterized, {UXID, params}} = Event.__schema__(:type, :id)

      assert params.monotonic == true
      assert params.compact_time == true

      # :small + compact_time => an 8-char timestamp and 3 random bytes (5 chars).
      ids = for _ <- 1..10, do: UXID.autogenerate(params)

      assert Enum.all?(ids, &(String.length(&1) == String.length("evt_") + 8 + 5))
      assert ids == Enum.sort(ids)
    end
  end

  describe "deterministic: true keys" do
    test "raise when minted without from:" do
      assert_raise ArgumentError, ~r/:export is declared deterministic: true/, fn ->
        DeterministicIDs.generate!(:export)
      end

      assert_raise ArgumentError, ~r/must be minted with from:/, fn ->
        DeterministicIDs.generate(:export)
      end
    end

    test "mint with from:" do
      id = DeterministicIDs.generate!(:export, from: "natural-key")

      assert id == DeterministicIDs.generate!(:export, from: "natural-key")
      assert UXID.deterministic?(id)
      assert String.starts_with?(id, "exp_")
    end

    test "an explicit nil from: is not enough" do
      assert_raise ArgumentError, ~r/must be minted with from:/, fn ->
        DeterministicIDs.generate!(:export, from: nil)
      end
    end

    test "the flag is a requirement, not a permission" do
      # An undeclared key may still be minted deterministically...
      assert UXID.deterministic?(DeterministicIDs.generate!(:note, from: "x"))
      # ...and is unaffected when minted normally.
      refute UXID.deterministic?(DeterministicIDs.generate!(:note))
    end

    test "the flag is surfaced on all/0 for app-side conformance tests" do
      by_key = Map.new(DeterministicIDs.all(), &{&1.key, &1})

      assert by_key[:export].deterministic
      refute by_key[:note].deterministic
    end
  end

  describe "legacy: metadata" do
    test "round-trips onto the entry and all/0" do
      by_key = Map.new(DeterministicIDs.all(), &{&1.key, &1})

      assert by_key[:enrichment].legacy == :uuid5_deferred
      assert by_key[:note].legacy == nil
    end

    test "carries no behavior - the key mints normally" do
      assert String.starts_with?(DeterministicIDs.generate!(:enrichment), "enr_")
    end
  end
end
