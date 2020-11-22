if Code.ensure_loaded?(Ecto) do
  defmodule Ecto.UXID do
    @moduledoc """
    Deprecated - use `UXID` instead.
    """

    use Ecto.ParameterizedType

    require Logger

    @doc """
    The underlying schema type.
    """
    def type(_opts) do
      :string
    end

    def init(opts) do
      Logger.warn(
        "Ecto.UXID is deprecated and will be removed in a future version. Please use UXID istead."
      )

      Enum.into(opts, %{})
    end

    def cast(data, _params) do
      {:ok, data}
    end

    def load(data, _loader, _params) do
      {:ok, data}
    end

    def dump(data, _dumper, _params) do
      {:ok, data}
    end

    def autogenerate(opts) do
      Logger.warn(
        "Ecto.UXID is deprecated and will be removed in a future version. Please use UXID istead."
      )

      UXID.generate!(prefix: opts.prefix, rand_size: opts.rand_size)
    end
  end
end
