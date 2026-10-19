defmodule UXID.Corpus.Monotonic do
  @moduledoc false

  # The monotonic rule of guides/wire-format.md ("Monotonic generation"),
  # replayed from recorded draws instead of a random source. Dev-only: it
  # lives under lib/mix/, outside the package's files.
  #
  # UXID.Monotonic draws its seed and its steps from the CSPRNG and takes no
  # injected draws, so the corpus generator cannot drive it to a fixed
  # sequence. This module is the same rule over the draws a monotonic case
  # carries: the first id takes `initial_seed`; every later id keeps the last
  # time and adds the next of `steps`; when the sum does not fit the field,
  # that id takes the last time plus one and `overflow_seed`. The generator
  # turns each {time, value} into an id by calling the library with `time:`
  # and `rand:`. UXID.CorpusTest runs the real UXID.Monotonic and replays what
  # it drew through this module, so the two cannot drift apart unnoticed.
  #
  # A case never carries a time later than the last one: that path reseeds
  # from the random source, a draw a case has no field for.

  import Bitwise

  @typedoc "The draws and times of one monotonic run, the field `width` bytes wide."
  @type draws :: %{
          width: pos_integer(),
          times: [non_neg_integer()],
          initial_seed: non_neg_integer(),
          steps: [pos_integer()],
          overflow_seed: non_neg_integer() | nil
        }

  @doc """
  Returns the {time, field value} of every id in the run, or the first rule
  the draws break.
  """
  @spec replay(draws()) :: {:ok, [{non_neg_integer(), non_neg_integer()}]} | {:error, String.t()}
  def replay(%{times: [first | rest], steps: steps, width: width} = draws) do
    max = 1 <<< (width * 8)
    max_step = 1 <<< (width * 4)

    cond do
      length(steps) != length(rest) ->
        {:error, "#{length(steps)} steps for #{length(rest)} ids after the first; one per id"}

      not in_field?(draws.initial_seed, max) ->
        {:error, "initial_seed #{inspect(draws.initial_seed)} does not fit #{width} bytes"}

      true ->
        start = {[{first, draws.initial_seed}], draws.overflow_seed}

        rest
        |> Enum.zip(steps)
        |> Enum.reduce_while({:ok, start}, &advance(&1, &2, max, max_step))
        |> finish()
    end
  end

  def replay(%{times: []}), do: {:error, "a monotonic case needs at least one time"}

  defp advance({time, step}, {:ok, {[{last_time, last} | _] = acc, seed}}, max, max_step) do
    cond do
      time > last_time ->
        {:halt,
         {:error, "time #{time} is later than the last time #{last_time}; it would reseed"}}

      step not in 1..max_step//1 ->
        {:halt, {:error, "step #{inspect(step)} is outside 1..#{max_step}"}}

      last + step < max ->
        {:cont, {:ok, {[{last_time, last + step} | acc], seed}}}

      not in_field?(seed, max) ->
        {:halt,
         {:error, "the step #{step} overflows the field and no unused overflow_seed fits it"}}

      true ->
        {:cont, {:ok, {[{last_time + 1, seed} | acc], :used}}}
    end
  end

  defp advance(_pair, error, _max, _max_step), do: {:halt, error}

  defp finish({:ok, {acc, :used}}), do: {:ok, Enum.reverse(acc)}
  defp finish({:ok, {acc, nil}}), do: {:ok, Enum.reverse(acc)}
  defp finish({:ok, {_acc, _seed}}), do: {:error, "overflow_seed is given but no step overflows"}
  defp finish({:error, _} = error), do: error

  defp in_field?(value, max), do: is_integer(value) and value >= 0 and value < max
end
