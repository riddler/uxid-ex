defmodule UXID.Registered do
  @moduledoc """
  Marks a module (typically an Ecto schema) as belonging to a `UXID.Registry`
  key, so the registry can assemble its runtime prefix → schema routing table by
  reflection at boot — *without* the base-layer registry ever naming the
  upper-layer schema module in code.

      defmodule MyApp.CRM.Contact do
        use Ecto.Schema
        use UXID.Registered, key: :contact
        @primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:contact)}
      end

  This defines `__uxid_key__/0`, the marker that `MyApp.IDs.build_routes!/1` /
  `verify!/1` collect. Every reference points **down** — the schema names a
  registry *key*, never the reverse — so a layered app keeps the correct
  dependency direction: the registry can live at the base layer while the
  schemas it routes to live above it. See `UXID.Registry` for the routing and
  boot-verification story.

  An app with its own base schema macro (`use MyApp.Schema`) can simply have that
  macro emit `def __uxid_key__(), do: ...` instead of using this mixin.
  """

  @doc false
  defmacro __using__(opts) do
    key = Keyword.get(opts, :key)

    unless is_atom(key) and not is_nil(key) do
      raise ArgumentError,
            "use UXID.Registered requires a :key atom, got: #{inspect(key)}"
    end

    quote do
      @doc false
      def __uxid_key__(), do: unquote(key)
    end
  end
end
