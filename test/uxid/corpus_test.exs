defmodule UXID.CorpusTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias UXID.Corpus
  alias UXID.Corpus.JSON
  alias UXID.Corpus.Monotonic

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
                 "conformance/invalid.json",
                 "conformance/manifest.json",
                 "conformance/monotonic.json"
               ]

      manifest = files["conformance/manifest.json"]

      assert manifest =~
               ~r/"files":\[\{"case_count":\d+,"file":"encode.json","kind":"encode"\},\{"case_count":\d+,"file":"deterministic.json","kind":"deterministic"\},\{"case_count":\d+,"file":"decode.json","kind":"decode"\},\{"case_count":\d+,"file":"invalid.json","kind":"invalid"\},\{"case_count":\d+,"file":"monotonic.json","kind":"monotonic"\}\]/

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

    # Sabotage: deterministic.exs drops `expected:` from the cus golden case
    # -> the list carries two vectors.
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

  describe "invalid cases" do
    # Sabotage: the decode clause of build_case/2 writes the authored error
    # instead of checking it against UXID.decode/1 -> the case is written.
    test "are refused when the decoder gives another reason" do
      sources = %{
        "invalid" => [%{slug: "short", decode: "usr_01hf7", expected_error: :invalid_character}]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "invalid/short"
      assert problem =~ "invalid_length"
    end

    # Sabotage: the {:ok, _codec} branch of the decode clause answers
    # {:refused, ...} -> a string that decodes is written as invalid.
    test "are refused when the string decodes" do
      sources = %{
        "invalid" => [
          %{slug: "fine", decode: "usr_01hf7yat000001", expected_error: :invalid_length}
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "invalid/fine"
      assert problem =~ "decodes"
    end

    # Sabotage: generation_error/3 answers {:refused, ...} after a build that
    # did not raise -> options the library accepts are written as invalid.
    test "are refused when the library builds the id" do
      sources = %{
        "invalid" => [
          %{
            slug: "accepted",
            generate: [size: :s, time: 1_700_000_000_000, rand: <<1, 2>>],
            expected_error: :rand_width_mismatch
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "invalid/accepted"
      assert problem =~ "builds an id"
    end

    # Sabotage: generation_error/3 skips the message check -> a rand_size
    # refusal is written under the rand width name.
    test "are refused when the library raises for a different refusal" do
      sources = %{
        "invalid" => [
          %{
            slug: "other",
            generate: [size: :xl, rand_size: 11, time: 1_700_000_000_000],
            expected_error: :rand_width_mismatch
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "invalid/other"
      assert problem =~ "rand_size must be at most"
    end

    # Sabotage: the :error branch of the generate clause calls
    # generation_error/3 with an empty fragment -> an unlisted name is written.
    test "are refused for a name outside the closed set" do
      sources = %{
        "invalid" => [
          %{
            slug: "unnamed",
            generate: [size: :xl, rand_size: 11, time: 1_700_000_000_000],
            expected_error: :too_much_randomness
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "not a generation error name"
    end

    # Sabotage: generate_input/1 drops the compact_time clause -> the input
    # carries "compact_time" instead of "compact".
    test "spell generation options as encode cases do" do
      sources = %{
        "invalid" => [
          %{
            slug: "guard",
            generate: [size: :s, compact_time: true, case: :upper, time: 1_065_151_889_408],
            expected_error: :compact_time_out_of_range
          }
        ]
      }

      assert {:ok, %{"conformance/invalid.json" => line}} = Corpus.build_files(sources)

      assert line ==
               ~s({"expected_error":"compact_time_out_of_range","id":"invalid/guard",) <>
                 ~s("input":{"generate":{"case":"upper","compact":true,"size":"s","time":1065151889408}}}\n)
    end
  end

  describe "monotonic cases" do
    # Sabotage: the monotonic build_case/2 passes `value` unchanged as a
    # one-byte rand -> the library raises a width error and the case fails.
    test "build every id with the library from the replayed draws" do
      sources = %{
        "monotonic" => [
          %{
            slug: "run",
            prefix: "usr",
            size: :s,
            compact: false,
            times: [1_700_000_000_000, 1_700_000_000_000],
            initial_seed: 65_535,
            steps: [1],
            overflow_seed: 0
          }
        ]
      }

      assert {:ok, %{"conformance/monotonic.json" => line}} = Corpus.build_files(sources)
      assert line =~ ~s("expected":["usr_01hf7yat00zzz1","usr_01hf7yat010000"])
    end

    # Sabotage: steppable/1 tests width >= 0 -> the 0-byte field reaches
    # the replay and an id is written for a refused request.
    test "are refused for a size and mode with no random field" do
      sources = %{
        "monotonic" => [
          %{
            slug: "xs",
            prefix: nil,
            size: :xs,
            compact: false,
            times: [1_700_000_000_000],
            initial_seed: 0,
            steps: []
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "no random field"
    end

    # Sabotage: json_safe/1 compares with > @max_json_integer * 2048 -> a
    # seed a JSON double rounds is written.
    test "are refused for an integer above 2^53 - 1" do
      sources = %{
        "monotonic" => [
          %{
            slug: "big",
            prefix: nil,
            size: :xl,
            compact: false,
            times: [1_700_000_000_000],
            initial_seed: 9_007_199_254_740_992,
            steps: []
          }
        ]
      }

      assert {:error, [problem]} = Corpus.build_files(sources)
      assert problem =~ "2^53 - 1"
    end
  end

  describe "the monotonic model" do
    # Sabotage: advance/4 keeps the call's time instead of the last time ->
    # the second id carries 9.
    test "keeps the last time when the clock moves back" do
      assert Monotonic.replay(draws(1, [10, 9], 5, [3])) == {:ok, [{10, 5}, {10, 8}]}
    end

    # Sabotage: advance/4 bumps to the call's time + 1 -> the overflow id
    # carries 9, not 11.
    test "bumps the last time by one on an overflow and takes the overflow seed" do
      assert Monotonic.replay(draws(1, [10, 8, 8], 250, [6, 2], 7)) ==
               {:ok, [{10, 250}, {11, 7}, {11, 9}]}
    end

    # Sabotage: the `last + step < max` test uses <= -> 255 + 1 does not
    # overflow and 256 is written into a one-byte field.
    test "overflows exactly at the field's size" do
      assert {:ok, [_, {10, 255}]} = Monotonic.replay(draws(1, [10, 10], 254, [1]))
      assert {:ok, [_, {11, 0}]} = Monotonic.replay(draws(1, [10, 10], 255, [1], 0))
    end

    # Sabotage: the step range is 1..max_step + 1 -> a step of 17 replays.
    test "refuses a step outside 1..2^(4w)" do
      assert {:ok, _} = Monotonic.replay(draws(1, [10, 10], 0, [16]))
      assert {:error, message} = Monotonic.replay(draws(1, [10, 10], 0, [17]))
      assert message =~ "outside 1..16"
      assert {:error, _} = Monotonic.replay(draws(1, [10, 10], 0, [0]))
    end

    # Sabotage: advance/4's later-time clause also requires step < 0 -> the
    # later call keeps stepping as if in the same millisecond.
    test "refuses a time later than the last" do
      assert {:error, message} = Monotonic.replay(draws(1, [10, 11], 0, [1]))
      assert message =~ "later than the last time"
    end

    # Sabotage: finish/1 accepts an unused seed -> {:ok, _}.
    test "refuses an overflow seed no step uses, and an overflow with no seed" do
      assert {:error, unused} = Monotonic.replay(draws(1, [10, 10], 0, [1], 5))
      assert unused =~ "no step overflows"
      assert {:error, missing} = Monotonic.replay(draws(1, [10, 10], 255, [1]))
      assert missing =~ "overflows the field"
    end

    # Sabotage: in_field?/2 accepts any value when max > 0 -> a 256 seed
    # replays.
    test "refuses a seed that does not fit the field, a step count off by one and no times" do
      assert {:error, seed} = Monotonic.replay(draws(1, [10], 256, []))
      assert seed =~ "does not fit"
      assert {:error, count} = Monotonic.replay(draws(1, [10, 10], 0, []))
      assert count =~ "one per id"
      assert {:error, _} = Monotonic.replay(draws(1, [], 0, []))
    end
  end

  describe "the monotonic model against UXID.Monotonic" do
    # The model is tied to the module by replaying what the module drew:
    # each run below calls the real UXID.Monotonic.next/3, reads every id's
    # time and field value, checks the rule the model assumes, recovers the
    # draws (the step is the difference; an overflow's step is the smallest
    # that overflows; the overflow seed is the value it took) and replays them.
    # Sabotage: the model's advance/4 keeps the call's time instead of the last
    # time -> the replayed times differ from the module's.
    test "replays a real one-byte run whose clock moves back, through an overflow" do
      t = 1_700_000_000_000
      times = Stream.cycle([t, t - 3, t, t - 1])
      run = real_run(1, times)

      assert Enum.any?(run, fn {_call, emitted, _value} -> emitted == t + 1 end),
             "a one-byte field overflows within the run"

      assert_model_matches(run, 1)
    end

    # Sabotage: the model's advance/4 adds step - 1 -> the replayed values fall
    # one short of the module's.
    test "replays a real two-byte same-millisecond run" do
      t = 1_700_000_000_000
      run = real_run(2, Stream.repeatedly(fn -> t end))

      assert_model_matches(run, 2)
    end
  end

  # Calls the real UXID.Monotonic until the first overflow and on to just
  # before a second one (at most 2000 calls), returning the call's time, the
  # id's time and its field value per id.
  defp real_run(width, times) do
    prefix = "corpus-model-#{System.unique_integer([:positive])}"

    run =
      times
      |> Stream.map(fn time ->
        {emitted, rand} = UXID.Monotonic.next(prefix, width, time)
        {time, emitted, :binary.decode_unsigned(rand)}
      end)
      |> Enum.take(2000)
      |> Enum.chunk_by(fn {_call, emitted, _value} -> emitted end)
      |> Enum.take(2)
      |> Enum.concat()

    UXID.Monotonic.reset(prefix, width)
    run
  end

  defp assert_model_matches([{first_time, first_time, seed} | _] = calls, width) do
    max = 1 <<< (width * 8)
    max_step = 1 <<< (width * 4)
    run = Enum.map(calls, fn {_call, emitted, value} -> {emitted, value} end)

    steps_and_overflow =
      run
      |> Enum.zip(tl(run))
      |> Enum.map(fn
        {{time, last}, {time, value}} ->
          # Same time: kept, strictly increasing, by a step in the range.
          assert (value - last) in 1..max_step
          {value - last, nil}

        {{last_time, last}, {time, value}} ->
          # An overflow: the last time plus one, reachable by one step.
          assert time == last_time + 1
          assert last + max_step >= max
          {max - last, value}
      end)

    assert Enum.all?(run, fn {time, _value} -> time in [first_time, first_time + 1] end)

    steps = Enum.map(steps_and_overflow, &elem(&1, 0))
    overflow_seed = Enum.find_value(steps_and_overflow, &elem(&1, 1))
    times = Enum.map(calls, fn {call, _emitted, _value} -> call end)

    assert Monotonic.replay(draws(width, times, seed, steps, overflow_seed)) == {:ok, run}
  end

  defp draws(width, times, initial_seed, steps, overflow_seed \\ nil) do
    %{
      width: width,
      times: times,
      initial_seed: initial_seed,
      steps: steps,
      overflow_seed: overflow_seed
    }
  end

  defp golden_sources(case_), do: %{"deterministic" => [case_]}
end
