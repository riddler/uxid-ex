# This is a modified version of Elixir Base to include crockford encoding
defmodule UXID.CrockfordBase32Test do
  use ExUnit.Case, async: true

  doctest UXID.CrockfordBase32
  import UXID.CrockfordBase32

  test "encode/1 can deal with empty strings" do
    assert "" == encode("")
  end

  test "encode/1 with one pad" do
    assert "CSQPYRG=" == encode("foob", padding: true)
  end

  test "encode/1 with three pads" do
    assert "CSQPY===" == encode("foo", padding: true)
  end

  test "encode/1 with four pads" do
    assert "CSQG====" == encode("fo", padding: true)
  end

  test "encode/1 with six pads" do
    assert "CSQPYRK1E8======" == encode("foobar", padding: true)
    assert "CR======" == encode("f", padding: true)
  end

  test "encode/1 with no pads" do
    assert "CSQPYRK1" == encode("fooba")
  end

  test "encode/2 with one pad and ignoring padding" do
    assert "CSQPYRG" == encode("foob", padding: false)
  end

  test "encode/2 with three pads and ignoring padding" do
    assert "CSQPY" == encode("foo", padding: false)
  end

  test "encode/2 with four pads and ignoring padding" do
    assert "CSQG" == encode("fo", padding: false)
  end

  test "encode/2 with six pads and ignoring padding" do
    assert "CSQPYRK1E8" == encode("foobar", padding: false)
  end

  test "encode/2 with no pads and ignoring padding" do
    assert "CSQPYRK1" == encode("fooba", padding: false)
  end

  test "encode/2 with lowercase" do
    assert "csqpyrk1" == encode("fooba", case: :lower)
  end

  test "decode/1 can deal with empty strings" do
    assert {:ok, ""} == decode("")
  end

  test "decode!/1 can deal with empty strings" do
    assert "" == decode!("")
  end

  test "decode/1 with one pad" do
    assert {:ok, "foob"} == decode("CSQPYRG=")
  end

  test "decode!/1 with one pad" do
    assert "foob" == decode!("CSQPYRG=")
  end

  test "decode/1 with three pads" do
    assert {:ok, "foo"} == decode("CSQPY===")
  end

  test "decode!/1 with three pads" do
    assert "foo" == decode!("CSQPY===")
  end

  test "decode/1 with four pads" do
    assert {:ok, "fo"} == decode("CSQG====")
  end

  test "decode!/1 with four pads" do
    assert "fo" == decode!("CSQG====")
  end

  test "decode/1 with six pads" do
    assert {:ok, "foobar"} == decode("CSQPYRK1E8======")
    assert {:ok, "f"} == decode("CS======")
  end

  test "decode!/1 with six pads" do
    assert "foobar" == decode!("CSQPYRK1E8======")
    assert "f" == decode!("CS======")
  end

  test "decode/1 with no pads" do
    assert {:ok, "fooba"} == decode("CSQPYRK1")
  end

  test "decode!/1 with no pads" do
    assert "fooba" == decode!("CSQPYRK1")
  end

  test "decode/1,2 error on non-alphabet digit" do
    assert :error == decode("CSQ)UOJ1")
    assert :error == decode("66X")
    assert :error == decode("abc", case: :lower)
  end

  test "decode!/1,2 error non-alphabet digit" do
    assert_raise ArgumentError, "non-alphabet digit found: \")\" (byte 41)", fn ->
      decode!("CSQ)UOJ1")
    end

    assert_raise ArgumentError, "non-alphabet digit found: \"c\" (byte 99)", fn ->
      decode!("cpnmuoj1e8======")
    end

    assert_raise ArgumentError, "non-alphabet digit found: \"C\" (byte 67)", fn ->
      decode!("CSQPYRK1E8======", case: :lower)
    end
  end

  test "decode/1 errors on incorrect padding" do
    assert :error == decode("CSQPYRG=====", padding: true)
  end

  test "decode!/1 errors on incorrect padding" do
    assert_raise ArgumentError, fn ->
      decode!("CSQPYRG=====", padding: true)
    end
  end

  test "decode/2 with lowercase" do
    assert {:ok, "fo"} == decode("csqp====", case: :lower)
  end

  test "decode!/2 with lowercase" do
    assert "fo" == decode!("csqp====", case: :lower)
  end

  test "decode/2 with mixed case" do
    assert {:ok, "fo"} == decode("cSQp====", case: :mixed)
  end

  test "decode!/2 with mixed case" do
    assert "fo" == decode!("cSQp====", case: :mixed)
  end

  test "decode/2 with one pad and ignoring padding" do
    assert {:ok, "foob"} == decode("CSQPYRG", padding: false)
  end

  test "decode!/2 with one pad and ignoring padding" do
    assert "foob" == decode!("CSQPYRG", padding: false)
  end

  test "decode/2 with three pads and ignoring padding" do
    assert {:ok, "foo"} == decode("CSQPY", padding: false)
  end

  test "decode!/2 with three pads and ignoring padding" do
    assert "foo" == decode!("CSQPY", padding: false)
  end

  test "decode/2 with four pads and ignoring padding" do
    assert {:ok, "fo"} == decode("CSQG", padding: false)
  end

  test "decode!/2 with four pads and ignoring padding" do
    assert "fo" == decode!("CSQG", padding: false)
  end

  test "decode/2 with six pads and ignoring padding" do
    assert {:ok, "foobar"} == decode("CSQPYRK1E8", padding: false)
  end

  test "decode!/2 with six pads and ignoring padding" do
    assert "foobar" == decode!("CSQPYRK1E8", padding: false)
  end

  test "decode/2 with no pads and ignoring padding" do
    assert {:ok, "fooba"} == decode("CSQPYRK1", padding: false)
  end

  test "decode!/2 with no pads and ignoring padding" do
    assert "fooba" == decode!("CSQPYRK1", padding: false)
  end

  test "decode/2 ignores incorrect padding when :padding is false" do
    assert {:ok, "foob"} == decode("CSQPYRG", padding: false)
  end

  test "decode!/2 ignores incorrect padding when :padding is false" do
    "foob" = decode!("CSQPYRG", padding: false)
  end

  test "decode/2 with :lower case and ignoring padding" do
    assert {:ok, "fo"} == decode("csqp", case: :lower, padding: false)
  end

  test "decode!/2 with :lower case and ignoring padding" do
    assert "fo" == decode!("csqp", case: :lower, padding: false)
  end

  test "decode/2 with :mixed case and ignoring padding" do
    assert {:ok, "fo"} == decode("cSQp====", case: :mixed, padding: false)
  end

  test "decode!/2 with :mixed case and ignoring padding" do
    assert "fo" == decode!("cSQp", case: :mixed, padding: false)
  end

  test "encode then decode is identity" do
    for {encode, decode} <- [
          {&encode/2, &decode!/2}
        ],
        encode_case <- [:upper, :lower],
        decode_case <- [:upper, :lower, :mixed],
        encode_case == decode_case or decode_case == :mixed,
        pad? <- [true, false],
        len <- 0..256 do
      data =
        0
        |> :lists.seq(len - 1)
        |> Enum.shuffle()
        |> IO.iodata_to_binary()

      expected =
        data
        |> encode.(case: encode_case, pad: pad?)
        |> decode.(case: decode_case, pad: pad?)

      assert data == expected,
             "identity did not match for #{inspect(data)} when #{inspect(encode)} (#{encode_case})"
    end
  end
end
