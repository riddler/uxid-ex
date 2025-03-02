if Code.ensure_loaded?(Ecto) do
  defmodule UXID.EctoType do
    use Ecto.ParameterizedType

    @type t :: String.t()

    @doc """
    Generates a loaded version of the UXID.
    """
    @impl Ecto.ParameterizedType
    def autogenerate(opts) do
      prefix = Map.get(opts, :prefix)
      size = Map.get(opts, :size)
      rand_size = Map.get(opts, :rand_size)

      UXID.generate!(prefix: prefix, size: size, rand_size: rand_size)
    end

    @doc """
    Returns the underlying schema type for a UXID.
    """
    @impl Ecto.ParameterizedType
    def type(_opts), do: :string

    @doc """
    Converts the options specified in the field macro into parameters to be used in other callbacks.
    """
    @impl Ecto.ParameterizedType
    def init(opts) do
      # validate_opts(opts)
      Enum.into(opts, %{})
    end

    @doc """
    Casts the given input to the UXID ParameterizedType with the given parameters.
    """
    @impl Ecto.ParameterizedType
    def cast(data, _params) do
      cast_binary(data)
    end

    defp cast_binary(nil), do: {:ok, nil}
    defp cast_binary(term) when is_binary(term), do: {:ok, term}
    defp cast_binary(_), do: :error

    @doc """
    The load/3 function is responsible for converting loaded database values into your custom type's format.
    """
    @impl Ecto.ParameterizedType
    def load(data, _loader, _params), do: {:ok, data}

    @doc """
    The dump/3 function converts your custom type into a format suitable for the database.
    Dumps the given term into an Ecto native type, in this case, :string.
    """
    @impl Ecto.ParameterizedType
    def dump(data, _dumper, _params), do: {:ok, data}
  end
end
