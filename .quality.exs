# Quality configuration for uxid.
#
#   mix quality                 - full gate. Run before every commit. The
#                                 stages it runs:
#                                   format        mix format --check-formatted
#                                   compile       dev + test, warnings as errors
#                                   dependencies  no unused dependencies
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
#
#   mix quality --profile loop  - inner loop while implementing: format,
#                                 compile, credo and only the tests covering
#                                 changed code, without coverage. Use between
#                                 edits; it is never evidence that the gate
#                                 is green.
#
# Agents: prefer `--format json --report -` when you want to route on results.
#
# Not run: the readme and diataxis stages stay off; doctor, gettext and
# sobelow are not installed; and the dependency stage's security audit needs
# mix_audit, which is not installed either.

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
  profiles: [
    loop: [
      stages: [:format, :compile, :credo, :test],
      test: [scope: :changed, coverage: false]
    ]
  ]
]
