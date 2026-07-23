defmodule UXID.Codec do
  @moduledoc """
  This represents a UXID during encoding with all of the fields split out.
  """

  defstruct [
    :case,
    :compact_time,
    :delimiter,
    # `deterministic` records the scheme: set true on the name-based (hash) path,
    # false/nil on the time-based path. It is stamped during encode (from a `from`
    # input) and during decode (from the leading `z`/`Z` marker).
    :deterministic,
    :encoded,
    # `from` holds the input string for a deterministic (name-based) UXID. When it
    # is a binary the encoder routes to the deterministic scheme instead of the
    # time/random one.
    :from,
    :monotonic,
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
          deterministic: boolean() | nil,
          encoded: String.t() | nil,
          from: String.t() | nil,
          monotonic: boolean() | [atom()] | nil,
          prefix: String.t() | nil,
          delimiter: String.t() | nil,
          rand_size: pos_integer() | :decode_not_supported | nil,
          rand: binary() | :decode_not_supported | nil,
          rand_encoded: String.t() | nil,
          size: atom() | nil,
          string: String.t() | nil,
          time: pos_integer() | nil,
          time_encoded: String.t() | nil
        }
end
