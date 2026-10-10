# Quality configuration for uxid.
#
#   mix quality                 - full gate. Run before every commit. The
#                                 stages it runs:
#                                   format        mix format --check-formatted
#                                   compile       dev + test, warnings as errors
#                                   dependencies  no unused dependencies, and
#                                                 mix_audit's security audit
#                                                 of the locked versions (it
#                                                 fetches the advisory
#                                                 database over the network)
#                                   credo         --strict, credo's own defaults
#                                                 (there is no .credo.exs)
#                                   tests         the whole suite with coverage,
#                                                 held to coveralls.json's
#                                                 minimum_coverage
#                                   dialyzer      PLT cached under priv/plts/
#                                   docs          builds the docs, fails on any
#                                                 ExDoc warning
#                                   doc_links     fails on the link rules ExDoc
#                                                 accepts silently
#                                   readme        fails on any README shape
#                                                 finding (What, Why, Install,
#                                                 Basic usage, a grouped
#                                                 Documentation map, under 250
#                                                 lines)
#
#   mix quality --profile loop  - inner loop while implementing: format,
#                                 compile, credo and only the tests covering
#                                 changed code, without coverage. Use between
#                                 edits; it is never evidence that the gate
#                                 is green.
#
# Agents: prefer `--format json --report -` when you want to route on results.
#
# Not run: the diataxis stage stays off; and doctor, gettext and sobelow are
# not installed.

[
  format: [
    check: true
  ],
  compile: [
    warnings_as_errors: true
  ],
  credo: [
    strict: true
  ],
  # The two documentation stages make this gate the pre-publish check for
  # the package's docs, locally and in CI. The Docs stage builds the docs
  # and fails on any ExDoc warning (a reference to a function that does not
  # exist, a link that resolves nowhere), which `mix docs` otherwise prints
  # and exits 0 on. The doc_links stage fails on the link rules ExDoc
  # accepts silently: a README relative link the package files do not ship,
  # a relative link in a Markdown extra to a file that is not itself an
  # extra (moduledoc links are the Docs stage's), two extras sharing a
  # basename, and a link ExDoc rewrites to a different extra.
  # Both are `:auto`: on while `:ex_doc` is installed, which it is in :dev.
  docs: [
    enabled: :auto
  ],
  doc_links: [
    enabled: :auto
  ],
  # The README stage checks the README keeps the shape of an introduction
  # and a map (it reads headings, paragraphs and code blocks, never the
  # prose). At severity :error any finding fails the gate, so the README
  # cannot drift into a manual one section at a time.
  readme: [
    enabled: :auto,
    severity: :error
  ],
  profiles: [
    loop: [
      stages: [:format, :compile, :credo, :test],
      test: [scope: :changed, coverage: false]
    ]
  ]
]
