defmodule UXID.Encoder do
  @moduledoc """
  Encodes UXID structs into strings 
  """

  @default_rand_size 10
  @delimiter "_"

  def process(%UXID{} = struct) do
    uxid =
      struct
      |> ensure_time_and_rand_size()
      |> generate_id()
      |> prefix()

    {:ok, uxid}
  end

  # === Private helpers

  # Encode with 10 bytes of randomness (80 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5, r13::5,
           r14::5, r15::5, r16::5>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12), e(r13), e(r14), e(r15),
      e(r16)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 9 bytes of randomness (72 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5, r13::5,
           r14::5, r15::2>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12), e(r13), e(r14), e(r15)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 8 bytes of randomness (64 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5, r13::4>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12), e(r13)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 7 bytes of randomness (56 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::1>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 6 bytes of randomness (48 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::3>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 5 bytes of randomness (40 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::5, r8::5>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7), e(r8)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 4 bytes of randomness (32 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::5, r6::5, r7::2>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5), e(r6), e(r7)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 3 bytes of randomness (24 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::5, r5::4>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4), e(r5)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 2 bytes of randomness (16 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::5,
           r3::5, r4::1>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2), e(r3),
      e(r4)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 1 byte of randomness (8 bits)
  defp encode(
         <<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5, r1::5, r2::3>>
       ) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10), e(r1), e(r2)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 0 bytes of randomness
  defp encode(<<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5>>) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode(_), do: :error

  defp ensure_time_and_rand_size(%UXID{time: nil} = uxid),
    do: ensure_time_and_rand_size(%{uxid | time: System.system_time(:millisecond)})

  defp ensure_time_and_rand_size(%UXID{rand_size: nil} = uxid),
    do: ensure_time_and_rand_size(%{uxid | rand_size: @default_rand_size})

  defp ensure_time_and_rand_size(uxid), do: uxid

  defp generate_id(%UXID{time: time, rand_size: rand_size} = uxid) do
    string = encode(<<time::unsigned-size(48), :crypto.strong_rand_bytes(rand_size)::binary>>)
    %{uxid | encoded: string}
  end

  defp prefix(%UXID{prefix: nil, encoded: encoded} = uxid), do: %{uxid | string: encoded}

  defp prefix(%UXID{prefix: prefix, encoded: encoded} = uxid),
    do: %{uxid | string: prefix <> @delimiter <> encoded}

  @compile {:inline, e: 1}

  defp e(0), do: ?0
  defp e(1), do: ?1
  defp e(2), do: ?2
  defp e(3), do: ?3
  defp e(4), do: ?4
  defp e(5), do: ?5
  defp e(6), do: ?6
  defp e(7), do: ?7
  defp e(8), do: ?8
  defp e(9), do: ?9
  defp e(10), do: ?A
  defp e(11), do: ?B
  defp e(12), do: ?C
  defp e(13), do: ?D
  defp e(14), do: ?E
  defp e(15), do: ?F
  defp e(16), do: ?G
  defp e(17), do: ?H
  defp e(18), do: ?J
  defp e(19), do: ?K
  defp e(20), do: ?M
  defp e(21), do: ?N
  defp e(22), do: ?P
  defp e(23), do: ?Q
  defp e(24), do: ?R
  defp e(25), do: ?S
  defp e(26), do: ?T
  defp e(27), do: ?V
  defp e(28), do: ?W
  defp e(29), do: ?X
  defp e(30), do: ?Y
  defp e(31), do: ?Z
end
