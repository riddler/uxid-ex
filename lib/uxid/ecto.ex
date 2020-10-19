if Code.ensure_loaded?(Ecto) do
  defmodule Ecto.UXID do
    @moduledoc """
    An Ecto type for UXID strings.
    """

    use Ecto.ParameterizedType

    @doc """
    The underlying schema type.
    """
    def type(_opts), do: :string

    def init(opts) do
      # validate_opts(opts)
      Enum.into(opts, %{})
    end

    def cast(data, _params), do: {:ok, data}

    def load(data, _loader, _params), do: {:ok, data}

    def dump(data, _dumper, _params), do: {:ok, data}

    def autogenerate(opts),
      do: UXID.generate!(prefix: opts.prefix, rand_size: opts.rand_size)
  end
end
