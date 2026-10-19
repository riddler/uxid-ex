defmodule UXID.Corpus.JSON do
  @moduledoc false

  # A canonical JSON writer for the conformance corpus. Dev-only: it lives
  # under lib/mix/, outside the package's files.
  #
  # The corpus is byte-compared against what the generator writes, so the
  # encoding must not depend on map ordering or on a JSON library (none is a
  # dependency of this package, and the oldest supported Elixir has no JSON
  # module). The rules: object keys sorted by codepoint, no whitespace between
  # tokens, strings as UTF-8 with only the characters JSON requires escaped,
  # integers in decimal. Floats are refused: the corpus carries none.

  @type json ::
          nil
          | boolean()
          | integer()
          | String.t()
          | [json()]
          | %{optional(String.t() | atom()) => json()}

  @doc "Encodes `term` as one canonical JSON document, with no trailing newline."
  @spec encode(json()) :: String.t()
  def encode(term), do: term |> encode_term() |> IO.iodata_to_binary()

  @doc "Encodes a list of terms one per line, each line ended by a newline."
  @spec encode_lines([json()]) :: String.t()
  def encode_lines(terms) when is_list(terms),
    do: terms |> Enum.map(&[encode_term(&1), ?\n]) |> IO.iodata_to_binary()

  defp encode_term(nil), do: "null"
  defp encode_term(true), do: "true"
  defp encode_term(false), do: "false"
  defp encode_term(integer) when is_integer(integer), do: Integer.to_string(integer)
  defp encode_term(string) when is_binary(string), do: encode_string(string)

  defp encode_term(list) when is_list(list),
    do: [?[, list |> Enum.map(&encode_term/1) |> Enum.intersperse(?,), ?]]

  defp encode_term(map) when is_map(map) do
    members =
      map
      |> Enum.map(fn {key, value} -> {key_string(key), value} end)
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map(fn {key, value} -> [encode_string(key), ?:, encode_term(value)] end)
      |> Enum.intersperse(?,)

    [?{, members, ?}]
  end

  defp encode_term(other),
    do: raise(ArgumentError, "the corpus JSON writer cannot encode #{inspect(other)}")

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)

  defp encode_string(string) do
    unless String.valid?(string) do
      raise ArgumentError, "the corpus JSON writer needs UTF-8 strings, got: #{inspect(string)}"
    end

    [?", escape(string, []), ?"]
  end

  defp escape(<<>>, acc), do: Enum.reverse(acc)
  defp escape(<<?", rest::binary>>, acc), do: escape(rest, ["\\\"" | acc])
  defp escape(<<?\\, rest::binary>>, acc), do: escape(rest, ["\\\\" | acc])
  defp escape(<<?\n, rest::binary>>, acc), do: escape(rest, ["\\n" | acc])
  defp escape(<<?\r, rest::binary>>, acc), do: escape(rest, ["\\r" | acc])
  defp escape(<<?\t, rest::binary>>, acc), do: escape(rest, ["\\t" | acc])

  defp escape(<<char, rest::binary>>, acc) when char < 0x20,
    do: escape(rest, [control_escape(char) | acc])

  defp escape(<<char, rest::binary>>, acc), do: escape(rest, [char | acc])

  defp control_escape(char) do
    hex = char |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(4, "0")
    "\\u" <> hex
  end
end
