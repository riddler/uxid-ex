defmodule UXID.Codec do
  @moduledoc """
  This represents a UXID during encoding with all of the fields split out.
  """

  defstruct [
    :case,
    :compact_time,
    :delimiter,
    :encoded,
    :prefix,
    :rand_size,
    :rand,
    :rand_encoded,
    :size,
    :string,
    :time,
    :time_encoded
  ]

  @typedoc "A UXID struct during encoding"
  @type t() :: %__MODULE__{
          case: atom() | nil,
          compact_time: boolean() | nil,
          encoded: String.t() | nil,
          prefix: String.t() | nil,
          delimiter: String.t() | nil,
          rand_size: pos_integer() | nil,
          rand: binary() | nil,
          rand_encoded: String.t() | nil,
          size: atom() | nil,
          string: String.t() | nil,
          time: pos_integer() | nil,
          time_encoded: String.t() | nil
        }
end
