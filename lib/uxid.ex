defmodule UXID do
  @moduledoc """
  Documentation for `UXID`.
  """
  alias UXID.Decoder
  alias UXID.Encoder

  defstruct [:encoded, :prefix, :rand_size, :string, :time]

  # @doc """
  # Decodes a UXID from a string.

  # ## Examples

  #     iex> UXID.decode("01E9VB3RWNAR89HSKMS84K9HCS")
  #     %UXID{time_encoded: "01E9VB3RWN", randomness_encoded: "AR89HSKMS84K9HCS"}

  def decode(string) do
    Decoder.process(string)
  end

  def generate!(opts \\ []) do
    case generate(opts) do
      {:ok, uxid} -> uxid
      {:error, error} -> raise error
      :error -> raise "Unknown error occurred"
    end
  end

  def generate(opts \\ []) do
    {:ok, %__MODULE__{string: string}} = new(opts)
    {:ok, string}
  end

  def new(opts \\ []) do
    timestamp = Keyword.get(opts, :time, System.system_time(:millisecond))
    rand_size = Keyword.get(opts, :rand_size, 10)
    prefix = Keyword.get(opts, :prefix)

    %__MODULE__{
      prefix: prefix,
      rand_size: rand_size,
      time: timestamp
    }
    |> Encoder.process()
  end
end
