defmodule UXID.TestSupport.Account do
  @moduledoc false
  use Ecto.Schema

  # Draws every id option from the registry — the single source of truth. A
  # conformance test then reflects over this schema to prove its prefix is
  # registered (see UXID.RegistryConformanceTest and guides/registry.md).
  @primary_key {:id, UXID, [autogenerate: true] ++ UXID.TestSupport.IDs.field_opts(:org)}
  schema "accounts" do
  end
end
