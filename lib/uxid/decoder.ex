defmodule UXID.Decoder do
  @moduledoc """
  Decodes UXID strings into Codec structs
  """
  import Bitwise

  alias UXID.Codec

  @delimiter "_"

  @spec process(Codec.t()) :: {:ok, Codec.t()} | {:error, String.t()}
  def process(%Codec{} = struct) do
    decoded =
      struct
      |> separate_prefix()
      |> decode_size()
      |> ensure_compact_time()
      |> separate_encoded()
      |> decode_time()
      |> decode_rand()
      |> decode_rand_size()

    {:ok, decoded}
  end

  @spec separate_prefix(Codec.t()) :: Codec.t()
  def separate_prefix(%Codec{prefix: nil, string: uxid_string} = struct) do
    %{prefix: prefix, encoded: encoded} = split_uxid_string(uxid_string)
    %{struct | prefix: prefix, encoded: encoded}
  end

  def separate_prefix(%Codec{prefix: _, string: _} = struct) do
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

  def decode_size(%Codec{encoded: encoded} = struct) when is_binary(encoded) do
    # Infer size AND compact mode from total encoded length
    # Compact mode produces 1 char shorter lengths for small/large/xlarge
    {size, compact} =
      case String.length(encoded) do
        10 -> {:xsmall, false}
        13 -> {:small, true}
        14 -> {:small, false}
        18 -> {:medium, false}
        21 -> {:large, true}
        22 -> {:large, false}
        25 -> {:xlarge, true}
        26 -> {:xlarge, false}
        _ -> {:unknown, false}
      end

    %{struct | size: size, compact_time: compact}
  end

  def decode_size(struct), do: struct

  defp ensure_compact_time(%Codec{compact_time: explicit} = uxid) when not is_nil(explicit) do
    # compact_time already determined by decode_size or explicitly set
    uxid
  end

  defp ensure_compact_time(%Codec{compact_time: nil, size: size} = uxid) do
    # Fallback: use global policy if compact_time wasn't inferred from length
    compact = UXID.compact_small_times() && size in [:xs, :xsmall, :s, :small]
    %{uxid | compact_time: compact}
  end

  def separate_encoded(%Codec{compact_time: true, encoded: encoded} = struct) do
    # Compact mode: 8 character timestamp (40 bits, perfect 5-bit alignment)
    {time_encoded, rand_encoded} = String.split_at(encoded, 8)
    %{struct | time_encoded: time_encoded, rand_encoded: rand_encoded}
  end

  def separate_encoded(%Codec{encoded: encoded} = struct) do
    # Standard mode: 10 character timestamp
    {time_encoded, rand_encoded} = String.split_at(encoded, 10)
    %{struct | time_encoded: time_encoded, rand_encoded: rand_encoded}
  end

  def decode_rand(%Codec{rand_encoded: _rand_encoded} = struct) do
    %{struct | rand: :decode_not_supported}
  end

  def decode_rand_size(%Codec{rand_encoded: _rand_encoded} = struct) do
    %{struct | rand_size: :decode_not_supported}
  end

  # Decode UXID and extract timestamp
  @spec decode_time(Codec.t()) :: Codec.t()
  # Compact 40-bit timestamp (8 characters, perfect 5-bit alignment)
  # Requires epoch reconstruction to restore full 48-bit timestamp
  def decode_time(
        %Codec{
          compact_time: true,
          time_encoded: <<t1::8, t2::8, t3::8, t4::8, t5::8, t6::8, t7::8, t8::8>>
        } = struct
      ) do
    # Decode the 40-bit compact timestamp
    <<time_40::40>> =
      <<d(t1)::5, d(t2)::5, d(t3)::5, d(t4)::5, d(t5)::5, d(t6)::5, d(t7)::5, d(t8)::5>>

    # Reconstruct full 48-bit timestamp using current time to infer epoch
    current_time = System.system_time(:millisecond)
    current_epoch = current_time >>> 40

    # Combine current epoch with decoded 40-bit time
    reconstructed = current_epoch <<< 40 ||| time_40

    # If reconstructed time is significantly in the future (>1 day),
    # it's likely from the previous 40-bit cycle (edge case near epoch boundary)
    time =
      if reconstructed - current_time > 86_400_000 do
        # Subtract one 40-bit epoch (2^40 milliseconds ≈ 34.8 years)
        reconstructed - 0x10000000000
      else
        reconstructed
      end

    %{struct | time: time}
  end

  # Standard 48-bit timestamp (10 characters)
  def decode_time(
        %Codec{
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
  # Support lowercase as well
  def d(?a), do: 10
  def d(?b), do: 11
  def d(?c), do: 12
  def d(?d), do: 13
  def d(?e), do: 14
  def d(?f), do: 15
  def d(?g), do: 16
  def d(?h), do: 17
  def d(?j), do: 18
  def d(?k), do: 19
  def d(?m), do: 20
  def d(?n), do: 21
  def d(?p), do: 22
  def d(?q), do: 23
  def d(?r), do: 24
  def d(?s), do: 25
  def d(?t), do: 26
  def d(?v), do: 27
  def d(?w), do: 28
  def d(?x), do: 29
  def d(?y), do: 30
  def d(?z), do: 31
end
