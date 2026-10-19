defmodule Mix.Tasks.Uxid.Corpus do
  @shortdoc "Writes or checks the conformance corpus under conformance/"

  @moduledoc false

  # Writes conformance/<kind>.json and conformance/manifest.json from the
  # authored source under conformance/source/, by calling the library.
  # Dev-only: this file is outside the package's files, and
  # conformance/README.md is its documentation.
  #
  #     mix uxid.corpus          # regenerate and write the case files and manifest
  #     mix uxid.corpus --check  # regenerate in memory and byte-compare; write nothing,
  #                              # fail on any difference (the gate's Corpus stage)
  #
  # A case that fails to build (a golden vector the library disagrees with, an
  # encode case that does not decode back) prints every failing case and
  # writes nothing. The logic is UXID.Corpus's; this task only reads, writes
  # and compares files.

  use Mix.Task

  @requirements ["app.config"]
  @source_dir "conformance/source"

  @impl Mix.Task
  def run(args) do
    check? = "--check" in args

    case @source_dir |> UXID.Corpus.load_sources() |> UXID.Corpus.build_files() do
      {:ok, files} -> if check?, do: check(files), else: write(files)
      {:error, errors} -> refuse(errors)
    end
  end

  defp write(files) do
    Enum.each(files, fn {path, content} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end)

    Mix.shell().info("Wrote #{map_size(files)} files under conformance/.")
  end

  defp check(files) do
    stale =
      files
      |> Enum.reject(fn {path, content} -> File.read(path) == {:ok, content} end)
      |> Enum.map(fn {path, _content} -> path end)
      |> Enum.sort()

    case stale do
      [] ->
        Mix.shell().info("conformance/ matches the generator.")

      paths ->
        Enum.each(paths, &Mix.shell().error("stale: #{&1}"))

        Mix.raise(
          "#{length(paths)} corpus file(s) differ from what the generator writes " <>
            "(a hand edit, or a source or library change not regenerated). " <>
            "Run `mix uxid.corpus` and review the diff; never edit a case file or the hash."
        )
    end
  end

  @spec refuse([String.t()]) :: no_return()
  defp refuse(errors) do
    Enum.each(errors, &Mix.shell().error/1)
    Mix.raise("The corpus did not build (#{length(errors)} problem(s)); nothing was written.")
  end
end
