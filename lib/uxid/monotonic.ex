defmodule UXID.Monotonic do
  @moduledoc """
  Process-local monotonic counter backing UXID's `monotonic:` mode.

  All state lives in the process dictionary — no GenServer, no ETS, no shared
  state — so callers stay `async: true` safe. Each BEAM process maintains its
  own independent sequence per `{prefix, rand_size}`.

  The random field is treated as one big-endian unsigned integer. The first ID
  in a given millisecond seeds it with full CSPRNG bytes; each subsequent ID in
  the same millisecond increments by 1. Because the encoding is big-endian and
  the Crockford alphabet is ASCII-monotonic, integer order equals encoded
  lexical order, so incrementing also sorts after — preserving K-sortability
  within the millisecond.
  """
  import Bitwise

  @doc """
  Returns `{time, rand_bytes}` for a monotonic generation.

  `time` may be bumped forward by 1ms if the counter overflowed the field
  within a single millisecond. `rand_bytes` is exactly `rand_size` bytes.
  """
  def next(prefix, rand_size, time) do
    key = {__MODULE__, prefix, rand_size}
    max = 1 <<< (rand_size * 8)

    case Process.get(key) do
      {last_time, last_int} when time <= last_time ->
        # same ms, or clock moved backward: keep last_time, increment
        int = last_int + 1

        if int < max do
          store(key, last_time, int, rand_size)
        else
          # overflow: spin one ms forward, fresh seed
          store(key, last_time + 1, seed(rand_size), rand_size)
        end

      _ ->
        # later ms (or no prior state): fresh random seed
        store(key, time, seed(rand_size), rand_size)
    end
  end

  @doc """
  Clears the counter for `{prefix, rand_size}` in the current process.

  Intended for tests and utilities; generation never requires it.
  """
  def reset(prefix, rand_size), do: Process.delete({__MODULE__, prefix, rand_size})

  defp seed(rand_size), do: :crypto.strong_rand_bytes(rand_size) |> :binary.decode_unsigned()

  defp store(key, time, int, rand_size) do
    Process.put(key, {time, int})
    {time, <<int::unsigned-size(rand_size * 8)>>}
  end
end
