defmodule UXID.Decoder do
  @moduledoc """
  Encodes UXID structs into strings
  """

  @delimiter "_"

  @spec process(UXID.t()) :: %UXID{}
  def process(%UXID{} = struct) do
    decoded =
      struct
      |> separate_prefix()
      |> separate_encoded()
      |> decode_time()
      |> decode_size()
      |> decode_rand()
      |> decode_rand_size()

    {:ok, decoded}
  end

  @spec separate_prefix(UXID.t()) :: UXID.t({})
  def separate_prefix(%UXID{prefix: nil, string: uxid_string} = struct) do
    %{prefix: prefix, encoded: encoded} = split_uxid_string(uxid_string)
    %{struct | prefix: prefix, encoded: encoded}
  end

  def separate_prefix(%UXID{prefix: _, string: _} = struct) do
    struct
  end

  defp split_uxid_string(uxid_string) do
    uxid_string
    |> String.split(@delimiter)
    |> case do
      [encoded] ->
        %{prefix: nil, encoded: encoded}

      split ->
        {encoded, prefix_parts} = List.pop_at(split, -1)
        %{prefix: Enum.join(prefix_parts, @delimiter), encoded: encoded}
    end
  end

  def separate_encoded(%UXID{encoded: encoded} = struct) do
    # Encoded Timestamp is always 10 characters
    {time_encoded, rand_encoded} = String.split_at(encoded, 10)
    %{struct | time_encoded: time_encoded, rand_encoded: rand_encoded}
  end

  def decode_size(%UXID{rand_encoded: _rand_encoded} = struct) do
    %{struct | size: :decode_not_supported}
  end

  def decode_rand(%UXID{rand_encoded: _rand_encoded} = struct) do
    %{struct | rand: :decode_not_supported}
  end

  def decode_rand_size(%UXID{rand_encoded: _rand_encoded} = struct) do
    %{struct | rand_size: :decode_not_supported}
  end

  # Decode UXID and extract timestamp
  @spec decode_time(UXID.t()) :: DateTime.t()
  def decode_time(
        %UXID{
          time_encoded: <<t1::8, t2::8, t3::8, t4::8, t5::8, t6::8, t7::8, t8::8, t9::8, t10::8>>
        } = struct
      ) do
    <<time::48>> =
      <<d(t1)::3, d(t2)::5, d(t3)::5, d(t4)::5, d(t5)::5, d(t6)::5, d(t7)::5, d(t8)::5, d(t9)::5,
        d(t10)::5>>

    %{struct | time: time}
  end

  def d(?0), do: 0
  def d(?1), do: 1
  def d(?2), do: 2
  def d(?3), do: 3
  def d(?4), do: 4
  def d(?5), do: 5
  def d(?6), do: 6
  def d(?7), do: 7
  def d(?8), do: 8
  def d(?9), do: 9
  def d(?A), do: 10
  def d(?B), do: 11
  def d(?C), do: 12
  def d(?D), do: 13
  def d(?E), do: 14
  def d(?F), do: 15
  def d(?G), do: 16
  def d(?H), do: 17
  def d(?J), do: 18
  def d(?K), do: 19
  def d(?M), do: 20
  def d(?N), do: 21
  def d(?P), do: 22
  def d(?Q), do: 23
  def d(?R), do: 24
  def d(?S), do: 25
  def d(?T), do: 26
  def d(?V), do: 27
  def d(?W), do: 28
  def d(?X), do: 29
  def d(?Y), do: 30
  def d(?Z), do: 31
end
