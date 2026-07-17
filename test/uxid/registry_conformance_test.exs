defmodule UXID.RegistryConformanceTest do
  # Proves the "every schema draws its id prefix from the registry" pattern that
  # guides/registry.md documents. The two helpers below are mirrored verbatim in
  # that guide, so keep them in sync.
  use ExUnit.Case, async: true

  alias UXID.TestSupport.{Account, IDs}

  # Ecto stores a UXID field as a parameterized type; pull its :prefix back out.
  defp uxid_prefix(schema, field) do
    case schema.__schema__(:type, field) do
      {:parameterized, {UXID, %{prefix: prefix}}} -> prefix
      {:parameterized, UXID, %{prefix: prefix}} -> prefix
      _ -> nil
    end
  end

  # Every Ecto schema in an app whose (single) primary key is a UXID.
  defp uxid_schemas(app) do
    for mod <- Application.spec(app, :modules) || [],
        Code.ensure_loaded?(mod),
        function_exported?(mod, :__schema__, 1),
        [pk] <- [mod.__schema__(:primary_key)],
        prefix = uxid_prefix(mod, pk),
        prefix != nil,
        do: {mod, prefix}
  end

  test "uxid_prefix/2 extracts the registered prefix from a schema" do
    assert uxid_prefix(Account, :id) == "org"
  end

  test "uxid_schemas/1 discovers UXID-keyed schemas in the app" do
    assert {Account, "org"} in uxid_schemas(:uxid)
  end

  test "every UXID-keyed schema draws its prefix from the registry" do
    for {schema, prefix} <- uxid_schemas(:uxid) do
      assert prefix in IDs.prefixes(),
             "#{inspect(schema)} uses unregistered UXID prefix #{inspect(prefix)}"
    end
  end
end
