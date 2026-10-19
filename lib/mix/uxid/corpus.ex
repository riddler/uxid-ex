defmodule UXID.Corpus do
  @moduledoc false

  # Builds the conformance corpus under conformance/ from the authored source
  # under conformance/source/, by calling the library. Dev-only: it lives under
  # lib/mix/, outside the package's files. `mix uxid.corpus` is the I/O shell
  # around build_files/1; everything that decides what a file holds is here.
  #
  # One kind is one source file (conformance/source/<kind>.exs, evaluating to
  # a list of authored cases), one case file (conformance/<kind>.json) and one
  # manifest entry, in the order of @kinds. Adding a kind is a source file, an
  # entry in @kinds and a build_case/2 clause.

  import Bitwise

  alias UXID.Corpus.JSON
  alias UXID.Corpus.Monotonic

  @kinds ["encode", "deterministic", "decode", "invalid", "monotonic"]
  @corpus_dir "conformance"
  @manifest_path "conformance/manifest.json"
  @corpus_version 1

  @sizes [:xs, :s, :m, :l, :xl]
  @decoded_sizes %{xsmall: "xs", small: "s", medium: "m", large: "l", xlarge: "xl"}

  # Crockford Base32 values by character, both cases; used only to read a
  # standard time back out of a body for the 10 and 18 ambiguity check.
  @alphabet ~c"0123456789abcdefghjkmnpqrstvwxyz"

  # The decode refusal reasons UXID.decode/1 names.
  @decode_errors [:empty, :invalid_length, :invalid_character]

  # The generation errors, named by the option that caused each. The library
  # raises ArgumentError for all of them; the names are the corpus's (listed in
  # guides/wire-format.md, "Generation errors"). The message fragment ties each
  # name to the refusal that raised it, so a case cannot carry the name of a
  # different refusal than the one the library made.
  @generation_errors %{
    compact_time_out_of_range: "compact_time cannot encode",
    rand_width_mismatch: "rand: must be exactly",
    rand_size_too_large: "rand_size must be at most",
    from_with_monotonic: "from: (deterministic mode) and monotonic: true",
    rand_with_from: "rand: and from: are mutually exclusive",
    rand_with_monotonic: "rand: cannot be used with monotonic"
  }

  # Every integer a case carries stays at or below 2^53 - 1, so a runner whose
  # JSON parser reads numbers as doubles reads each one exactly.
  @max_json_integer (1 <<< 53) - 1

  @typedoc "Relative path from the project root mapped to the exact bytes it holds."
  @type file_map :: %{String.t() => binary()}

  @typedoc "Authored cases per kind."
  @type sources :: %{String.t() => [map()]}

  @doc "The case kinds, in manifest order."
  @spec kinds() :: [String.t()]
  def kinds(), do: @kinds

  @doc "Evaluates every kind's source file under `dir`."
  @spec load_sources(Path.t()) :: sources()
  def load_sources(dir) do
    Map.new(@kinds, fn kind ->
      {cases, _binding} = Code.eval_file(Path.join(dir, kind <> ".exs"))
      {kind, cases}
    end)
  end

  @doc """
  Returns every case file and the manifest as a file map, or every problem
  found. Nothing is returned for writing when any case fails: an authored
  golden vector the library disagrees with, an encode case that does not
  decode back, a duplicate id, or an input the library refuses.
  """
  @spec build_files(sources()) :: {:ok, file_map()} | {:error, [String.t()]}
  def build_files(sources) do
    results = Enum.map(@kinds, &build_kind(&1, Map.get(sources, &1, [])))

    case Enum.flat_map(results, fn {_kind, _cases, errors} -> errors end) do
      [] -> {:ok, assemble(results)}
      errors -> {:error, errors}
    end
  end

  @doc """
  The corpus hash: `sha256:` and the lowercase hex SHA-256 of the given file
  contents concatenated in order.
  """
  @spec hash([binary()]) :: String.t()
  def hash(contents) do
    digest = :crypto.hash(:sha256, contents)
    "sha256:" <> Base.encode16(digest, case: :lower)
  end

  defp build_kind(kind, authored) do
    built = Enum.map(authored, &build_one(kind, &1))
    cases = for {:ok, built_case} <- built, do: built_case
    errors = for {:error, error} <- built, do: error

    {kind, cases, errors ++ duplicate_ids(cases)}
  end

  defp build_one(kind, %{slug: slug} = authored) do
    id = kind <> "/" <> slug

    case build_case(kind, authored) do
      {:ok, input, expected} -> {:ok, %{"id" => id, "input" => input, "expected" => expected}}
      {:refused, input, name} -> {:ok, %{"id" => id, "input" => input, "expected_error" => name}}
      {:error, problem} -> {:error, id <> ": " <> problem}
    end
  rescue
    error in [ArgumentError, FunctionClauseError, KeyError, MatchError] ->
      {:error, kind <> "/" <> slug <> ": " <> Exception.message(error)}
  end

  defp duplicate_ids(cases) do
    cases
    |> Enum.frequencies_by(& &1["id"])
    |> Enum.filter(fn {_id, count} -> count > 1 end)
    |> Enum.map(fn {id, count} -> "#{id}: the id is used #{count} times" end)
    |> Enum.sort()
  end

  # --- encode

  defp build_case("encode", authored) do
    %{prefix: prefix, size: size, compact: compact, case: letter_case, time: time} = authored
    rand = Base.decode16!(authored.rand, case: :lower)
    true = size in @sizes

    expected =
      UXID.generate!(
        prefix: prefix,
        size: size,
        compact_time: compact,
        case: letter_case,
        time: time,
        rand: rand
      )

    input = %{
      "prefix" => prefix,
      "size" => Atom.to_string(size),
      "compact" => compact,
      "case" => Atom.to_string(letter_case),
      "time" => time,
      "rand" => authored.rand
    }

    with :ok <- round_trip(expected, prefix, size, compact, time) do
      {:ok, input, expected}
    end
  end

  # --- deterministic

  defp build_case("deterministic", authored) do
    %{prefix: prefix, from: from, size: size, case: letter_case} = authored
    true = size in @sizes

    expected = UXID.generate!(prefix: prefix, from: from, size: size, case: letter_case)

    input = %{
      "prefix" => prefix,
      "from" => from,
      "size" => Atom.to_string(size),
      "case" => Atom.to_string(letter_case)
    }

    case Map.fetch(authored, :expected) do
      {:ok, ^expected} ->
        {:ok, input, expected}

      {:ok, golden} ->
        {:error, "the library answers #{expected}, the golden vector is #{golden}"}

      :error ->
        {:ok, input, expected}
    end
  end

  # --- decode

  defp build_case("decode", authored) do
    string =
      case authored do
        %{input: string} when is_binary(string) -> string
        %{encode: opts} when is_list(opts) -> UXID.generate!(opts)
      end

    case UXID.decode(string) do
      {:ok, codec} -> {:ok, string, decoded(codec)}
      {:error, reason} -> {:error, "#{string} is refused (#{reason}); a decode case decodes"}
    end
  end

  # --- invalid

  # A decode refusal: the reason UXID.decode/1 gives, checked against the
  # authored one so a case cannot silently change what it tests.
  defp build_case("invalid", %{decode: string, expected_error: want}) when is_binary(string) do
    case UXID.decode(string) do
      {:error, ^want} when want in @decode_errors ->
        {:refused, %{"decode" => string}, Atom.to_string(want)}

      {:error, reason} ->
        {:error, "#{inspect(string)} is refused for #{reason}, the case says #{want}"}

      {:ok, _codec} ->
        {:error, "#{inspect(string)} decodes; an invalid case is refused"}
    end
  end

  # A generation error: the library must raise ArgumentError for the option
  # set, with the refusal the authored name stands for.
  defp build_case("invalid", %{generate: opts, expected_error: want}) when is_list(opts) do
    case Map.fetch(@generation_errors, want) do
      {:ok, fragment} -> generation_error(opts, want, fragment)
      :error -> {:error, "#{want} is not a generation error name"}
    end
  end

  # --- monotonic

  # The case's draws are replayed through the monotonic rule
  # (UXID.Corpus.Monotonic) and every id is built by the library with `time:`
  # and `rand:`, monotonic off, so no random source and no PRNG enters the
  # expected strings.
  defp build_case("monotonic", authored) do
    %{prefix: prefix, size: size, compact: compact, times: times} = authored
    true = size in @sizes
    overflow_seed = Map.get(authored, :overflow_seed)
    {:ok, %{rand_size: width}} = UXID.new(size: size, compact_time: compact, monotonic: false)

    input = %{
      "prefix" => prefix,
      "size" => Atom.to_string(size),
      "compact" => compact,
      "times" => times,
      "initial_seed" => authored.initial_seed,
      "steps" => authored.steps,
      "overflow_seed" => overflow_seed
    }

    draws = %{
      width: width,
      times: times,
      initial_seed: authored.initial_seed,
      steps: authored.steps,
      overflow_seed: overflow_seed
    }

    with :ok <- steppable(width),
         :ok <- json_safe([overflow_seed, authored.initial_seed | times ++ authored.steps]),
         {:ok, values} <- Monotonic.replay(draws) do
      expected =
        Enum.map(values, fn {time, value} ->
          UXID.generate!(
            prefix: prefix,
            size: size,
            compact_time: compact,
            case: :lower,
            monotonic: false,
            time: time,
            rand: <<value::unsigned-size(width * 8)>>
          )
        end)

      {:ok, input, expected}
    end
  end

  defp generation_error(opts, name, fragment) do
    UXID.generate!(opts)
    {:error, "the library builds an id for #{inspect(opts)}; an invalid case raises"}
  rescue
    error in ArgumentError ->
      message = Exception.message(error)

      if String.contains?(message, fragment),
        do: {:refused, %{"generate" => generate_input(opts)}, Atom.to_string(name)},
        else: {:error, "the library raises #{inspect(message)}, not #{name}"}
  end

  # The options of a generation case, spelt as an encode case spells them:
  # `compact` for compact_time, atoms as strings, `rand` as lowercase hex.
  defp generate_input(opts) do
    Map.new(opts, fn
      {:compact_time, value} -> {"compact", value}
      {:rand, bytes} when is_binary(bytes) -> {"rand", Base.encode16(bytes, case: :lower)}
      {key, value} when is_boolean(value) or is_nil(value) -> {Atom.to_string(key), value}
      {key, value} when is_atom(value) -> {Atom.to_string(key), Atom.to_string(value)}
      {key, value} -> {Atom.to_string(key), value}
    end)
  end

  # The codec's type has no 0 width, but a standard xs resolves to one.
  defp steppable(width) do
    if width > 0, do: :ok, else: {:error, "the size and mode have no random field to step"}
  end

  defp json_safe(integers) do
    case Enum.find(integers, &(is_integer(&1) and &1 > @max_json_integer)) do
      nil -> :ok
      big -> {:error, "#{big} is above 2^53 - 1, which a JSON double cannot carry exactly"}
    end
  end

  defp decoded(codec) do
    %{
      "prefix" => codec.prefix,
      "size" => Map.fetch!(@decoded_sizes, codec.size),
      "compact" => codec.compact_time,
      "deterministic" => codec.deterministic,
      "time" => codec.time
    }
  end

  # Every encode case decodes back to its prefix (an empty prefix reads as
  # none), size, compact flag and time. Compact xs and compact m bodies have
  # the lengths of standard xs and m bodies, so they decode to the standard
  # reading the wire format page names: the same size, a standard time, and
  # that time read from the first 10 body characters.
  defp round_trip(string, prefix, size, compact, time) do
    {:ok, codec} = UXID.decode(string)
    got = decoded(codec)

    want =
      if compact and size in [:xs, :m] do
        %{compact: false, time: standard_reading(codec.encoded)}
      else
        %{compact: compact, time: time}
      end

    want =
      Map.merge(want, %{
        prefix: if(prefix == "", do: nil, else: prefix),
        size: Atom.to_string(size),
        deterministic: false
      })

    got = %{
      prefix: got["prefix"],
      size: got["size"],
      compact: got["compact"],
      deterministic: got["deterministic"],
      time: got["time"]
    }

    if got == want,
      do: :ok,
      else: {:error, "#{string} decodes to #{inspect(got)}, expected #{inspect(want)}"}
  end

  defp standard_reading(body) do
    [first | rest] =
      body
      |> String.slice(0, 10)
      |> String.downcase()
      |> String.to_charlist()
      |> Enum.map(fn char -> Enum.find_index(@alphabet, &(&1 == char)) end)

    <<time::48>> =
      :erlang.list_to_bitstring([<<rem(first, 8)::3>> | for(v <- rest, do: <<v::5>>)])

    time
  end

  # --- assembly

  defp assemble(results) do
    files =
      Enum.map(results, fn {kind, cases, _errors} ->
        {kind, kind <> ".json", cases, JSON.encode_lines(cases)}
      end)

    manifest = %{
      "corpus_version" => @corpus_version,
      "files" =>
        Enum.map(files, fn {kind, file, cases, _content} ->
          %{"kind" => kind, "file" => file, "case_count" => length(cases)}
        end),
      "corpus_hash" => hash(Enum.map(files, fn {_kind, _file, _cases, content} -> content end))
    }

    files
    |> Map.new(fn {_kind, file, _cases, content} -> {Path.join(@corpus_dir, file), content} end)
    |> Map.put(@manifest_path, JSON.encode(manifest) <> "\n")
  end
end
