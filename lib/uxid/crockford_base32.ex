defmodule UXID.CrockfordBase32 do
  import Bitwise

  @moduledoc """
  This module provides data encoding and decoding functions
  according to [Crockford Base32](https://www.crockford.com/base32.html)

  ## Crockford's Base 32 (UX focused - can be read over the phone) alphabet

  | Value | Encoding | Value | Encoding | Value | Encoding | Value | Encoding |
  |------:|:---------|------:|:---------|------:|:---------|------:|:---------|
  |     0 | 0        |     9 | 9        |    18 | J        |    27 | V        |
  |     1 | 1        |    10 | A        |    19 | K        |    28 | W        |
  |     2 | 2        |    11 | B        |    20 | M        |    29 | X        |
  |     3 | 3        |    12 | C        |    21 | N        |    30 | Y        |
  |     4 | 4        |    13 | D        |    22 | P        |    31 | Z        |
  |     5 | 5        |    14 | E        |    23 | Q        |       |          |
  |     6 | 6        |    15 | F        |    24 | R        | (pad) | =        |
  |     7 | 7        |    16 | G        |    25 | S        |       |          |
  |     8 | 8        |    17 | H        |    26 | T        |       |          |

  """

  b32crockford_alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

  defmacrop encode_pair(alphabet, case, value) do
    quote do
      case unquote(value) do
        unquote(encode_pair_clauses(alphabet, case))
      end
    end
  end

  defp encode_pair_clauses(alphabet, case) when case in [:sensitive, :upper] do
    shift = shift(alphabet)

    alphabet
    |> Enum.with_index()
    |> encode_clauses(shift)
  end

  defp encode_pair_clauses(alphabet, :lower) do
    shift = shift(alphabet)

    alphabet
    |> Stream.map(fn c -> if c in ?A..?Z, do: c - ?A + ?a, else: c end)
    |> Enum.with_index()
    |> encode_clauses(shift)
  end

  defp shift(alphabet) do
    alphabet
    |> length()
    |> :math.log2()
    |> round()
  end

  defp encode_clauses(alphabet, shift) do
    for {encoding1, value1} <- alphabet,
        {encoding2, value2} <- alphabet do
      encoding = bsl(encoding1, 8) + encoding2
      value = bsl(value1, shift) + value2
      [clause] = quote(do: (unquote(value) -> unquote(encoding)))
      clause
    end
  end

  def phony(alphabet) do
    encode_pair_clauses(alphabet, :lower)
    maybe_pad("", "", "", "")
  end

  defmacrop decode_char(alphabet, case, encoding) do
    quote do
      case unquote(encoding) do
        unquote(decode_char_clauses(alphabet, case))
      end
    end
  end

  defp decode_char_clauses(alphabet, case) when case in [:sensitive, :upper] do
    clauses =
      alphabet
      |> Enum.with_index()
      |> decode_clauses()

    clauses ++ bad_digit_clause()
  end

  defp decode_char_clauses(alphabet, :lower) do
    {uppers, rest} =
      alphabet
      |> Stream.with_index()
      |> Enum.split_with(fn {encoding, _} -> encoding in ?A..?Z end)

    lowers = Enum.map(uppers, fn {encoding, value} -> {encoding - ?A + ?a, value} end)

    if length(uppers) > length(rest) do
      decode_mixed_clauses(lowers, rest)
    else
      decode_mixed_clauses(rest, lowers)
    end
  end

  defp decode_char_clauses(alphabet, :mixed) when length(alphabet) == 16 do
    alphabet = Enum.with_index(alphabet)

    lowers =
      alphabet
      |> Stream.filter(fn {encoding, _} -> encoding in ?A..?Z end)
      |> Enum.map(fn {encoding, value} -> {encoding - ?A + ?a, value} end)

    decode_mixed_clauses(alphabet, lowers)
  end

  defp decode_char_clauses(alphabet, :mixed) when length(alphabet) == 32 do
    clauses =
      alphabet
      |> Stream.with_index()
      |> Enum.flat_map(fn {encoding, value} = pair ->
        if encoding in ?A..?Z do
          [pair, {encoding - ?A + ?a, value}]
        else
          [pair]
        end
      end)
      |> decode_clauses()

    clauses ++ bad_digit_clause()
  end

  defp decode_mixed_clauses(first, second) do
    first_clauses = decode_clauses(first)
    second_clauses = decode_clauses(second) ++ bad_digit_clause()

    join_clause =
      quote do
        encoding ->
          case encoding do
            unquote(second_clauses)
          end
      end

    first_clauses ++ join_clause
  end

  defp decode_clauses(alphabet) do
    for {encoding, value} <- alphabet do
      [clause] = quote(do: (unquote(encoding) -> unquote(value)))
      clause
    end
  end

  defp bad_digit_clause() do
    quote do
      c ->
        raise ArgumentError,
              "non-alphabet digit found: #{inspect(<<c>>, binaries: :as_strings)} (byte #{c})"
    end
  end

  defp maybe_pad(body, "", _, _), do: body
  defp maybe_pad(body, tail, false, _), do: body <> tail

  defp maybe_pad(body, tail, _, group_size) do
    case group_size - rem(byte_size(tail), group_size) do
      ^group_size -> body <> tail
      6 -> body <> tail <> "======"
      5 -> body <> tail <> "====="
      4 -> body <> tail <> "===="
      3 -> body <> tail <> "==="
      2 -> body <> tail <> "=="
      1 -> body <> tail <> "="
    end
  end

  for {base, alphabet} <- [
        "32crockford": b32crockford_alphabet
      ],
      case <- [:upper, :lower] do
    pair = :"enc#{base}_#{case}_pair"
    char = :"enc#{base}_#{case}_char"
    do_encode = :"do_encode#{base}"

    defp unquote(pair)(value) do
      encode_pair(unquote(alphabet), unquote(case), value)
    end

    defp unquote(char)(value) do
      value
      |> unquote(pair)()
      |> band(0x00FF)
    end

    defp unquote(do_encode)(_, <<>>, _), do: <<>>

    defp unquote(do_encode)(unquote(case), data, pad?) do
      split = 5 * div(byte_size(data), 5)
      <<main::size(split)-binary, rest::binary>> = data

      main =
        for <<c1::10, c2::10, c3::10, c4::10 <- main>>, into: <<>> do
          <<
            unquote(pair)(c1)::16,
            unquote(pair)(c2)::16,
            unquote(pair)(c3)::16,
            unquote(pair)(c4)::16
          >>
        end

      tail =
        case rest do
          <<c1::10, c2::10, c3::10, c4::2>> ->
            <<
              unquote(pair)(c1)::16,
              unquote(pair)(c2)::16,
              unquote(pair)(c3)::16,
              unquote(char)(bsl(c4, 3))::8
            >>

          <<c1::10, c2::10, c3::4>> ->
            <<unquote(pair)(c1)::16, unquote(pair)(c2)::16, unquote(char)(bsl(c3, 1))::8>>

          <<c1::10, c2::6>> ->
            <<unquote(pair)(c1)::16, unquote(pair)(bsl(c2, 4))::16>>

          <<c1::8>> ->
            <<unquote(pair)(bsl(c1, 2))::16>>

          <<>> ->
            <<>>
        end

      maybe_pad(main, tail, pad?, 8)
    end
  end

  for {base, alphabet} <- [
        "32crockford": b32crockford_alphabet
      ],
      case <- [:upper, :lower, :mixed] do
    fun = :"dec#{base}_#{case}"
    do_decode = :"do_decode#{base}"

    defp unquote(fun)(encoding) do
      decode_char(unquote(alphabet), unquote(case), encoding)
    end

    defp unquote(do_decode)(_, <<>>, _), do: <<>>

    defp unquote(do_decode)(unquote(case), string, pad?) do
      segs = div(byte_size(string) + 7, 8) - 1
      <<main::size(segs)-binary-unit(64), rest::binary>> = string

      main =
        for <<c1::8, c2::8, c3::8, c4::8, c5::8, c6::8, c7::8, c8::8 <- main>>, into: <<>> do
          <<
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            unquote(fun)(c4)::5,
            unquote(fun)(c5)::5,
            unquote(fun)(c6)::5,
            unquote(fun)(c7)::5,
            unquote(fun)(c8)::5
          >>
        end

      case rest do
        <<c1::8, c2::8, ?=, ?=, ?=, ?=, ?=, ?=>> ->
          <<main::bits, unquote(fun)(c1)::5, bsr(unquote(fun)(c2), 2)::3>>

        <<c1::8, c2::8, c3::8, c4::8, ?=, ?=, ?=, ?=>> ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            bsr(unquote(fun)(c4), 4)::1
          >>

        <<c1::8, c2::8, c3::8, c4::8, c5::8, ?=, ?=, ?=>> ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            unquote(fun)(c4)::5,
            bsr(unquote(fun)(c5), 1)::4
          >>

        <<c1::8, c2::8, c3::8, c4::8, c5::8, c6::8, c7::8, ?=>> ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            unquote(fun)(c4)::5,
            unquote(fun)(c5)::5,
            unquote(fun)(c6)::5,
            bsr(unquote(fun)(c7), 3)::2
          >>

        <<c1::8, c2::8, c3::8, c4::8, c5::8, c6::8, c7::8, c8::8>> ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            unquote(fun)(c4)::5,
            unquote(fun)(c5)::5,
            unquote(fun)(c6)::5,
            unquote(fun)(c7)::5,
            unquote(fun)(c8)::5
          >>

        <<c1::8, c2::8>> when not pad? ->
          <<main::bits, unquote(fun)(c1)::5, bsr(unquote(fun)(c2), 2)::3>>

        <<c1::8, c2::8, c3::8, c4::8>> when not pad? ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            bsr(unquote(fun)(c4), 4)::1
          >>

        <<c1::8, c2::8, c3::8, c4::8, c5::8>> when not pad? ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            unquote(fun)(c4)::5,
            bsr(unquote(fun)(c5), 1)::4
          >>

        <<c1::8, c2::8, c3::8, c4::8, c5::8, c6::8, c7::8>> when not pad? ->
          <<
            main::bits,
            unquote(fun)(c1)::5,
            unquote(fun)(c2)::5,
            unquote(fun)(c3)::5,
            unquote(fun)(c4)::5,
            unquote(fun)(c5)::5,
            unquote(fun)(c6)::5,
            bsr(unquote(fun)(c7), 3)::2
          >>

        _ ->
          raise ArgumentError, "incorrect padding"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Public

  @doc """
  Encodes a binary string into a base 32 encoded string using Crockford's
  alphabet.

  ## Options

  The accepted options are:

    * `:case` - specifies the character case to use when encoding
    * `:padding` - specifies whether to apply padding

  The values for `:case` can be:

    * `:upper` - uses upper case characters (default)
    * `:lower` - uses lower case characters

  The values for `:padding` can be:

    * `true` - pad the output string to the nearest multiple of 8
    * `false` - omit padding from the output string (default)

  ## Examples

      iex> UXID.CrockfordBase32.encode("foobar")
      "CSQPYRK1E8"

      iex> UXID.CrockfordBase32.encode("foobar", case: :lower)
      "csqpyrk1e8"

      iex> UXID.CrockfordBase32.encode("foobar", padding: true)
      "CSQPYRK1E8======"

  """
  @spec encode(binary, keyword) :: binary
  def encode(data, opts \\ []) when is_binary(data) do
    case = Keyword.get(opts, :case, :upper)
    pad? = Keyword.get(opts, :padding, false)
    do_encode32crockford(case, data, pad?)
  end

  @doc """
  Decodes a base 32 encoded string with Crockford's alphabet
  into a binary string.

  ## Options

  The accepted options are:

    * `:case` - specifies the character case to accept when decoding
    * `:padding` - specifies whether to require padding

  The values for `:case` can be:

    * `:upper` - only allows upper case characters (default)
    * `:lower` - only allows lower case characters
    * `:mixed` - allows mixed case characters

  The values for `:padding` can be:

    * `true` - requires the input string to be padded to the nearest multiple of 8
    * `false` - ignores padding from the input string (default)

  ## Examples

      iex> UXID.CrockfordBase32.decode("CSQPYRK1E8")
      {:ok, "foobar"}

      iex> UXID.CrockfordBase32.decode("csqpyrk1e8", case: :lower)
      {:ok, "foobar"}

      iex> UXID.CrockfordBase32.decode("csqPyRK1E8", case: :mixed)
      {:ok, "foobar"}

      iex> UXID.CrockfordBase32.decode("CSQPYRK1E8======", padding: true)
      {:ok, "foobar"}

  """
  @spec decode(binary, keyword) :: {:ok, binary} | :error
  def decode(string, opts \\ []) do
    {:ok, decode!(string, opts)}
  rescue
    ArgumentError -> :error
  end

  @doc """
  Decodes a base 32 encoded string with extended crockfordadecimal alphabet
  into a binary string.

  An `ArgumentError` exception is raised if the padding is incorrect or
  a non-alphabet character is present in the string.

  ## Options

  The accepted options are:

    * `:case` - specifies the character case to accept when decoding
    * `:padding` - specifies whether to require padding

  The values for `:case` can be:

    * `:upper` - only allows upper case characters (default)
    * `:lower` - only allows lower case characters
    * `:mixed` - allows mixed case characters

  The values for `:padding` can be:

    * `true` - requires the input string to be padded to the nearest multiple of 8 (default)
    * `false` - ignores padding from the input string

  ## Examples

      iex> UXID.CrockfordBase32.decode!("CSQPYRK1E8")
      "foobar"

      iex> UXID.CrockfordBase32.decode!("csqpyrk1e8", case: :lower)
      "foobar"

      iex> UXID.CrockfordBase32.decode!("csqPyRK1E8", case: :mixed)
      "foobar"

      iex> UXID.CrockfordBase32.decode!("CSQPYRK1E8======", padding: true)
      "foobar"

  """
  @spec decode!(binary, keyword) :: binary
  def decode!(string, opts \\ []) when is_binary(string) do
    case = Keyword.get(opts, :case, :upper)
    pad? = Keyword.get(opts, :padding, false)
    do_decode32crockford(case, string, pad?)
  end
end
