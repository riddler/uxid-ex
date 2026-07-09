# Quality Configuration
#
# This file allows you to customize the behavior of `mix quality`.
#
# Configuration is merged in this order (later wins):
# 1. Defaults
# 2. Auto-detected tool availability
# 3. This file (.quality.exs)
# 4. CLI arguments (--quick, --skip-*, etc.)

[
  # Global options
  # quick: false,  # Skip dialyzer and coverage enforcement

  # Compilation options
  # compile: [
  #   warnings_as_errors: true
  # ],

  # Credo static analysis
  # credo: [
  #   enabled: :auto,  # :auto | true | false
  #   strict: true,
  #   all: false
  # ],

  # Dialyzer type checking
  # dialyzer: [
  #   enabled: :auto  # :auto | true | false
  # ],

  # Doctor documentation coverage
  # doctor: [
  #   enabled: :auto,  # :auto | true | false
  #   summary_only: false
  # ],

  # Gettext translation completeness
  # gettext: [
  #   enabled: :auto  # :auto | true | false
  # ],

  # Dependencies (unused deps and security audit)
  # dependencies: [
  #   enabled: :auto,
  #   check_unused: true,
  #   audit: :auto  # Requires mix_audit package
  # ],

  # Test options
  # test: [
  #   args: ["--only", "integration"]  # Extra args for mix test/coveralls
  # ]

  # Note: Coverage threshold is configured in coveralls.json or mix.exs
]
