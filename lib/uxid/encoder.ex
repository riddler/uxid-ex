defmodule UXID.Encoder do
  @moduledoc """
  Encodes UXID structs into strings 
  """

  @default_rand_size 10
  @delimiter "_"

  def process(%UXID{} = struct) do
    uxid =
      struct
      |> ensure_time()
      |> ensure_rand_size()
      |> ensure_rand()
      |> ensure_case()
      |> encode()
      |> prefix()

    {:ok, uxid}
  end

  # === Private helpers

  defp ensure_time(%UXID{time: nil} = uxid),
    do: %{uxid | time: System.system_time(:millisecond)}

  defp ensure_time(uxid),
    do: uxid

  defp ensure_rand_size(%UXID{rand_size: nil, size: :xs} = uxid),
    do: %{uxid | rand_size: 0}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :xsmall} = uxid),
    do: %{uxid | rand_size: 0}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :s} = uxid),
    do: %{uxid | rand_size: 2}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :small} = uxid),
    do: %{uxid | rand_size: 2}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :m} = uxid),
    do: %{uxid | rand_size: 5}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :medium} = uxid),
    do: %{uxid | rand_size: 5}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :l} = uxid),
    do: %{uxid | rand_size: 7}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :large} = uxid),
    do: %{uxid | rand_size: 7}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :xl} = uxid),
    do: %{uxid | rand_size: 10}

  defp ensure_rand_size(%UXID{rand_size: nil, size: :xlarge} = uxid),
    do: %{uxid | rand_size: 10}

  defp ensure_rand_size(%UXID{rand_size: nil} = uxid),
    do: %{uxid | rand_size: @default_rand_size}

  defp ensure_rand_size(uxid), do: uxid

  defp ensure_rand(%UXID{rand_size: rand_size, rand: nil} = uxid),
    do: %{uxid | rand: :crypto.strong_rand_bytes(rand_size)}

  defp ensure_rand(uxid), do: uxid

  defp ensure_case(%UXID{case: nil} = uxid),
    do: %{uxid | case: UXID.encode_case()}

  defp ensure_case(%UXID{case: encode_case} = uxid),
    do: %{uxid | case: encode_case}

  defp encode(%UXID{} = input) do
    uxid =
      input
      |> encode_time()
      |> encode_rand()

    %{uxid | encoded: uxid.time_encoded <> uxid.rand_encoded}
  end

  defp encode_time(%UXID{case: case, time: time, time_encoded: nil} = uxid) do
    string = encode_time(<<time::unsigned-size(48)>>, case)
    %{uxid | time_encoded: string}
  end

  defp encode_time(<<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5>>, :lower) do
    <<el(t1), el(t2), el(t3), el(t4), el(t5), el(t6), el(t7), el(t8), el(t9), el(t10)>>
  catch
    :error -> :error
  else
    time_encoded -> time_encoded
  end

  defp encode_time(<<t1::3, t2::5, t3::5, t4::5, t5::5, t6::5, t7::5, t8::5, t9::5, t10::5>>, _upper) do
    <<e(t1), e(t2), e(t3), e(t4), e(t5), e(t6), e(t7), e(t8), e(t9), e(t10)>>
  catch
    :error -> :error
  else
    time_encoded -> time_encoded
  end

  defp encode_rand(%UXID{case: case, rand_size: rand_size, rand_encoded: nil} = uxid) do
    string =
      rand_size
      |> :crypto.strong_rand_bytes()
      |> encode_rand(case)

    %{uxid | rand_encoded: string}
  end

  # Encode with 10 bytes of randomness (80 bits)
  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5,
           r13::5, r14::5, r15::5, r16::5>>, :lower
       ) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7), el(r8), el(r9), el(r10), el(r11), el(r12),
      el(r13), el(r14), el(r15), el(r16)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5,
           r13::5, r14::5, r15::5, r16::5>>, _upper
       ) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12),
      e(r13), e(r14), e(r15), e(r16)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 9 bytes of randomness (72 bits)
  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5,
           r13::5, r14::5, r15::2>>, :lower
       ) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7), el(r8), el(r9), el(r10), el(r11), el(r12),
      el(r13), el(r14), el(r15)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5,
           r13::5, r14::5, r15::2>>, _upper
       ) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12),
      e(r13), e(r14), e(r15)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 8 bytes of randomness (64 bits)
  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5,
           r13::4>>, :lower
       ) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7), el(r8), el(r9), el(r10), el(r11), el(r12),
      el(r13)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::5,
           r13::4>>, _upper
       ) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12),
      e(r13)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 7 bytes of randomness (56 bits)
  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::1>>,
          :lower
       ) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7), el(r8), el(r9), el(r10), el(r11), el(r12)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(
         <<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::5, r11::5, r12::1>>,
          _upper
       ) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10), e(r11), e(r12)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 6 bytes of randomness (48 bits)
  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::3>>, :lower) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7), el(r8), el(r9), el(r10)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5, r9::5, r10::3>>, _upper) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7), e(r8), e(r9), e(r10)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 5 bytes of randomness (40 bits)
  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5>>, :lower) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7), el(r8)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::5, r8::5>>, _upper) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7), e(r8)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 4 bytes of randomness (32 bits)
  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::2>>, :lower) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5), el(r6), el(r7)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::5, r6::5, r7::2>>, _upper) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5), e(r6), e(r7)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 3 bytes of randomness (24 bits)
  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::4>>, :lower) do
    <<el(r1), el(r2), el(r3), el(r4), el(r5)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(<<r1::5, r2::5, r3::5, r4::5, r5::4>>, _upper) do
    <<e(r1), e(r2), e(r3), e(r4), e(r5)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 2 bytes of randomness (16 bits)
  defp encode_rand(<<r1::5, r2::5, r3::5, r4::1>>, :lower) do
    <<el(r1), el(r2), el(r3), el(r4)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(<<r1::5, r2::5, r3::5, r4::1>>, _upper) do
    <<e(r1), e(r2), e(r3), e(r4)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 1 byte of randomness (8 bits)
  defp encode_rand(<<r1::5, r2::3>>, :lower) do
    <<el(r1), el(r2)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  defp encode_rand(<<r1::5, r2::3>>, _upper) do
    <<e(r1), e(r2)>>
  catch
    :error -> :error
  else
    encoded -> encoded
  end

  # Encode with 0 bytes of randomness
  defp encode_rand("", _any), do: ""

  defp encode_rand(_, _any), do: :error

  defp prefix(%UXID{prefix: nil, encoded: encoded} = uxid), do: %{uxid | string: encoded}

  defp prefix(%UXID{prefix: prefix, encoded: encoded} = uxid),
    do: %{uxid | string: prefix <> @delimiter <> encoded}

  # Encode functions
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

  # Encode Lower functions
  @compile {:inline, el: 1}

  defp el(0), do: ?0
  defp el(1), do: ?1
  defp el(2), do: ?2
  defp el(3), do: ?3
  defp el(4), do: ?4
  defp el(5), do: ?5
  defp el(6), do: ?6
  defp el(7), do: ?7
  defp el(8), do: ?8
  defp el(9), do: ?9
  defp el(10), do: ?a
  defp el(11), do: ?b
  defp el(12), do: ?c
  defp el(13), do: ?d
  defp el(14), do: ?e
  defp el(15), do: ?f
  defp el(16), do: ?g
  defp el(17), do: ?h
  defp el(18), do: ?j
  defp el(19), do: ?k
  defp el(20), do: ?m
  defp el(21), do: ?n
  defp el(22), do: ?p
  defp el(23), do: ?q
  defp el(24), do: ?r
  defp el(25), do: ?s
  defp el(26), do: ?t
  defp el(27), do: ?v
  defp el(28), do: ?w
  defp el(29), do: ?x
  defp el(30), do: ?y
  defp el(31), do: ?z
end
