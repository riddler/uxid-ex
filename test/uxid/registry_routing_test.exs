defmodule UXID.RegistryRoutingTest do
  # Not async: build_routes!/verify! write global :persistent_term.
  use ExUnit.Case, async: false

  alias UXID.TestSupport.{Contact, RoutedIDs, Widget}

  describe "self-registration routing (verify!/1, build_routes!/1)" do
    test "verify! collects markers, validates, and fills schema_for/1" do
      assert :ok = RoutedIDs.verify!(otp_apps: [:uxid])

      assert RoutedIDs.routes() == %{widget: Widget}
      assert RoutedIDs.schema_for("wid_01h2xssfw0000000000000000") == Widget
    end

    test "build_routes!/1 returns the assembled table" do
      assert RoutedIDs.build_routes!(otp_apps: [:uxid]) == %{widget: Widget}
    end

    test "schema_for/1 is nil for an unregistered but well-formed prefix" do
      RoutedIDs.build_routes!(otp_apps: [:uxid])
      assert RoutedIDs.schema_for("gad_01h2xssfw0000000000000000") == nil
    end

    test "verify!/1 requires :otp_apps" do
      assert_raise ArgumentError, ~r/:otp_apps must be a non-empty list/, fn ->
        RoutedIDs.verify!()
      end
    end
  end

  describe "compile-time schema: literal still routes without a build" do
    alias UXID.TestSupport.IDs

    test "schema_for/1 resolves the literal with no routing table" do
      assert IDs.schema_for("contact_01h2xssfw0000000000000000") == Contact
    end
  end

  describe "prefixes/0" do
    test "lists registered prefixes in declaration order" do
      assert RoutedIDs.prefixes() == ["wid", "gad"]
    end
  end

  # The validation rules are exercised directly with crafted marker lists so the
  # failure cases don't depend on planting bad modules in the app's module list.
  describe "validate_markers!/3" do
    defp by_key(entries), do: Map.new(entries, &{&1.key, &1})

    defp entry(key, opts) do
      %{
        key: key,
        prefix: Atom.to_string(key),
        schema: Keyword.get(opts, :schema),
        route: Keyword.get(opts, :route, false)
      }
    end

    test "returns the routing map on a valid marker set" do
      bk = by_key([entry(:widget, route: true)])
      assert UXID.Registry.validate_markers!(Sample, bk, [{:widget, Widget}]) == %{widget: Widget}
    end

    test "raises when a marker names an unregistered key" do
      bk = by_key([entry(:widget, route: true)])

      assert_raise ArgumentError, ~r/reference keys not registered/, fn ->
        UXID.Registry.validate_markers!(Sample, bk, [{:nope, Widget}])
      end
    end

    test "raises when two modules claim the same key" do
      bk = by_key([entry(:widget, route: true)])

      assert_raise ArgumentError, ~r/claimed by multiple modules/, fn ->
        UXID.Registry.validate_markers!(Sample, bk, [{:widget, Widget}, {:widget, Contact}])
      end
    end

    test "raises when a route: true key resolves to no schema" do
      bk = by_key([entry(:widget, route: true)])

      assert_raise ArgumentError, ~r/marked route: true but not mapped/, fn ->
        UXID.Registry.validate_markers!(Sample, bk, [])
      end
    end

    test "a route: true key is satisfied by a compile-time schema literal" do
      bk = by_key([entry(:widget, route: true, schema: Widget)])
      assert UXID.Registry.validate_markers!(Sample, bk, []) == %{}
    end

    test "the same module re-registering a key is not a duplicate" do
      bk = by_key([entry(:widget, route: true)])

      assert UXID.Registry.validate_markers!(Sample, bk, [{:widget, Widget}, {:widget, Widget}]) ==
               %{widget: Widget}
    end
  end

  describe "UXID.Registered" do
    test "defines the marker function" do
      assert Widget.__uxid_key__() == :widget
    end

    test "rejects a missing/non-atom :key at compile time" do
      assert_raise ArgumentError, ~r/requires a :key atom/, fn ->
        Code.compile_string("""
        defmodule Sample.BadMarker do
          use UXID.Registered, key: "widget"
        end
        """)
      end
    end
  end
end
