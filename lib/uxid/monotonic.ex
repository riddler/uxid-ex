defmodule UXID.Monotonic do
  @moduledoc """
  Process-local monotonic counter backing UXID's `monotonic:` mode.

  All state lives in the process dictionary — no GenServer, no ETS, no shared
  state — so callers stay `async: true` safe. Each BEAM process maintains its
  own independent sequence per `{prefix, rand_size}`.

  The random field is treated as one big-endian unsigned integer. The first ID
  in a given millisecond seeds it with full CSPRNG bytes; each subsequent ID in
  the same millisecond advances it by a random positive step drawn from the
  CSPRNG. Because the step is always `>= 1` the sequence is strictly increasing,
  so IDs stay unique and — since the encoding is big-endian and the Crockford
  alphabet is ASCII-monotonic — integer order equals encoded lexical order,
  preserving K-sortability within the millisecond.

  The step is uniform over `[1, 2^(bits/2)]` where `bits` is the field width, so
  the next value is spread across a window of size `~2^(bits/2)` instead of being
  exactly `+1`. This is a *mitigation, not cryptographic unpredictability*: it
  removes trivial `…0004` → `…0005` enumeration and raises single-shot guess cost
  from certainty to `~1/2^(bits/2)`, but consecutive values still lie in a bounded
  window ahead. Low-entropy sizes (`:small` = 16 bits) remain low-entropy — don't
  use small/medium monotonic IDs as externally-enumerable, security-sensitive
  identifiers.
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
        # same ms, or clock moved backward: keep last_time, advance by a
        # random positive step (may overshoot max, hence the < guard below)
        int = last_int + step(rand_size)

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

  # Random increment for a same-millisecond ID: uniform over [1, 2^step_bits],
  # where step_bits is half the field width (the sqrt-of-the-field-space rule).
  # step_bits is a whole number of random bits masked from CSPRNG bytes, so the
  # draw is unbiased (no modulo bias). A step >= 1 preserves strict monotonicity.
  defp step(rand_size) do
    step_bits = div(rand_size * 8, 2)
    nbytes = max(1, div(step_bits + 7, 8))
    mask = (1 <<< step_bits) - 1

    (:crypto.strong_rand_bytes(nbytes) |> :binary.decode_unsigned() &&& mask) + 1
  end

  defp store(key, time, int, rand_size) do
    Process.put(key, {time, int})
    {time, <<int::unsigned-size(rand_size * 8)>>}
  end
end
