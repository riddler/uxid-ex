defmodule UXID do
  @moduledoc """
  Documentation for `UXID`.
  """
  alias UXID.Decoder

  defstruct [:encoded, :decoded, :time_encoded, :time, :randomness_encoded, :randomness]

  # @doc """
  # Decodes a UXID from a string.

  # ## Examples

  #     iex> UXID.decode("01E9VB3RWNAR89HSKMS84K9HCS")
  #     %UXID{time_encoded: "01E9VB3RWN", randomness_encoded: "AR89HSKMS84K9HCS"}

  def decode(string) do
    Decoder.process(string)
  end
end
