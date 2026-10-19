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

  alias UXID.Corpus.JSON

  @kinds ["encode", "deterministic", "decode"]
  @corpus_dir "conformance"
  @manifest_path "conformance/manifest.json"
  @corpus_version 1

  @sizes [:xs, :s, :m, :l, :xl]
  @decoded_sizes %{xsmall: "xs", small: "s", medium: "m", large: "l", xlarge: "xl"}

  # Crockford Base32 values by character, both cases; used only to read a
  # standard time back out of a body for the 10 and 18 ambiguity check.
  @alphabet ~c"0123456789abcdefghjkmnpqrstvwxyz"

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
