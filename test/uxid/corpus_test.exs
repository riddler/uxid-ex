defmodule UXID.CorpusTest do
  use ExUnit.Case, async: true

  alias UXID.Corpus
  alias UXID.Corpus.JSON

  @source_dir "conformance/source"

  describe "the canonical JSON writer" do
    # Sabotage: encode_term/1 for maps drops the Enum.sort_by -> keys come out
    # in map order and the nested object reads {"b":..,"a":..}.
    test "sorts object keys and writes no whitespace" do
      assert JSON.encode(%{"b" => [1, true, nil], "a" => %{"d" => false, "c" => "x"}}) ==
               ~s({"a":{"c":"x","d":false},"b":[1,true,null]})
    end

    # Sabotage: key_string/1 for atoms returns inspect(key) -> ":id" keys.
    test "writes atom keys as their names" do
      assert JSON.encode(%{id: 1}) == ~s({"id":1})
    end

    # Sabotage: escape/2 drops the backslash clause -> a lone backslash is
    # written unescaped.
    test "escapes quotes, backslashes and control characters" do
      assert JSON.encode(~s(a"b\\c\nd\re\tf) <> <<1>>) ==
               ~S("a\"b\\c\nd\re\tf\u0001")
    end

    # Sabotage: escape/2 escapes every byte above 0x7f as \u00xx -> the
    # two-byte "é" is written as two escapes.
    test "writes non-ASCII text as raw UTF-8" do
      assert JSON.encode("café") == ~s("café")
    end

    # Sabotage: encode_lines/1 joins with "\n" instead of ending every line
    # -> the last line has no newline.
    test "writes one document per line, every line ended by a newline" do
      assert JSON.encode_lines([%{"id" => 1}, %{"id" => 2}]) == ~s({"id":1}\n{"id":2}\n)
    end

    # Sabotage: the catch-all clause of encode_term/1 returns
    # inspect(other) -> a float is written instead of refused.
    test "refuses a float and an invalid string" do
      assert_raise ArgumentError, fn -> JSON.encode(1.5) end
      assert_raise ArgumentError, fn -> JSON.encode(<<0xFF>>) end
    end
  end

  describe "hash/1" do
    # Sabotage: hash/1 hashes only the first content -> the digest of "a",
    # not of "abc".
    test "is sha256: and the lowercase hex SHA-256 of the contents in order" do
      assert Corpus.hash(["a", "bc"]) ==
               "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    end
  end

  describe "build_files/1 over the authored source" do
    setup do
      {:ok, files} = @source_dir |> Corpus.load_sources() |> Corpus.build_files()
      %{files: files}
    end

    # Sabotage: assemble/1 drops the manifest -> no manifest key.
    test "writes every case file and a manifest in kind order", %{files: files} do
      assert Map.keys(files) |> Enum.sort() ==
               [
                 "conformance/decode.json",
                 "conformance/deterministic.json",
                 "conformance/encode.json",
                 "conformance/manifest.json"
               ]

      manifest = files["conformance/manifest.json"]

      assert manifest =~
               ~r/"files":\[\{"case_count":\d+,"file":"encode.json","kind":"encode"\},\{"case_count":\d+,"file":"deterministic.json","kind":"deterministic"\},\{"case_count":\d+,"file":"decode.json","kind":"decode"\}\]/

      assert manifest =~ ~s("corpus_version":1)
    end

    # Sabotage: the manifest hash reads the files in reverse order -> it
    # differs from the hash over encode, deterministic, decode.
    test "hashes the case files in manifest order", %{files: files} do
      contents = Enum.map(Corpus.kinds(), &files["conformance/#{&1}.json"])
      assert files["conformance/manifest.json"] =~ ~s("corpus_hash":"#{Corpus.hash(contents)}")
    end

    # Sabotage: case_count is length(cases) + 1 -> the count no longer
    # matches the lines in the file.
    test "counts the lines of each case file", %{files: files} do
      for kind <- Corpus.kinds() do
        lines = files["conformance/#{kind}.json"] |> String.split("\n", trim: true) |> length()

        assert files["conformance/manifest.json"] =~
                 ~s("case_count":#{lines},"file":"#{kind}.json")
      end
    end

    test "carries the three golden vectors of the deterministic test verbatim" do
      {cases, _binding} = Code.eval_file(Path.join(@source_dir, "deterministic.exs"))
      golden = for %{expected: expected} <- cases, do: expected

      assert golden == [
               "usr_zcvt7epac0t1ebcsjfyf7cwz25",
               "cus_zt9vnyfd85bff0",
               "zqz4cwzgyw8ks97869"
             ]
    end
  end

  describe "build_files/1 refuses" do
    # Sabotage: the deterministic build_case/2 ignores an authored expected
    # -> the wrong golden vector is written.
    test "when the library disagrees with a golden vector" do
      sources =
        golden_sources(%{
          slug: "golden",
          prefix: "usr",
          from: "alice@example.com",
          size: :xl,
          case: :lower,
          expected: "usr_zcvt7epac0t1ebcsjfyf7cwz26"
        })

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "deterministic/golden"
      assert problem =~ "usr_zcvt7epac0t1ebcsjfyf7cwz25"
    end

    # Sabotage: round_trip/5 always answers :ok -> a compact time the
    # decoder's clock reads into the previous window is written.
    test "when an encode case does not decode back to its time" do
      # The compact guard's last valid millisecond in the current window
      # (mid-2038): today's clock reads it back in the window before.
      sources = %{
        "encode" => [
          %{
            slug: "future-compact",
            prefix: "usr",
            size: :s,
            compact: true,
            case: :lower,
            time: 2_164_663_517_183,
            rand: "012345"
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "encode/future-compact"
      assert problem =~ "decodes to"
    end

    # Sabotage: the compact xs/m branch of round_trip/5 expects the authored
    # time -> every compact xs case is refused.
    test "nothing when a compact xs case decodes to the standard reading" do
      sources = %{
        "encode" => [
          %{
            slug: "xs-compact",
            prefix: nil,
            size: :xs,
            compact: true,
            case: :lower,
            time: 1_700_000_000_000,
            rand: "01"
          }
        ]
      }

      assert {:ok, %{"conformance/encode.json" => line}} = Corpus.build_files(sources)
      assert line =~ ~s("expected":"hf7yat0001")
    end

    # Sabotage: duplicate_ids/1 returns [] -> two cases share an id.
    test "when two cases share an id" do
      case_ = %{slug: "same", input: "usr_01hf7yat00"}

      assert {:error, [problem]} = Corpus.build_files(%{"decode" => [case_, case_]})
      assert problem =~ "decode/same"
    end

    # Sabotage: the decode build_case/2 writes the refusal as a case ->
    # {:ok, _}.
    test "when a decode input is refused" do
      assert {:error, [problem]} =
               Corpus.build_files(%{"decode" => [%{slug: "short", input: "usr_01hf7"}]})

      assert problem =~ "decode/short"
      assert problem =~ "invalid_length"
    end

    # Sabotage: build_one/2 rescues nothing -> the ArgumentError from the
    # compact guard escapes build_files/1.
    test "when the library raises for an input" do
      sources = %{
        "encode" => [
          %{
            slug: "guard",
            prefix: nil,
            size: :s,
            compact: true,
            case: :lower,
            time: 1_065_151_889_408,
            rand: "012345"
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "encode/guard"
    end
  end

  defp golden_sources(case_), do: %{"deterministic" => [case_]}
end
