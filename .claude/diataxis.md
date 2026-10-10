---
# The docs manifest the documentation tools read. Generated from the family's manifest
# table: change a key there and regenerate. The two prose lines below may be sharpened.
product: uxid
family: foundation
audience: "Elixir developers who want IDs a person can read, sort and route back to the resource they name."
tone: "plain, second person, no marketing"
terminology:
  use:
    - execution
    - chart
    - document
    - revision
  avoid:
    - "run (noun)"
    - workflow instance
example_world: none
docs_root: docs
quadrants:
  tutorials: docs/tutorials
  how_to: guides
  reference: guides
  explanation: guides
readme: README.md
reference_generator: ex_doc
publish: hexdocs
contributor_paths:
  - docs/adr
  - docs/plans
  - docs/spikes
  - docs/research
  - docs/design
  - docs/measurements
  - CLAUDE.md
executed_snippets: []
readme_max_lines: 250
---

User eXperience focused IDentifiers for Elixir: prefixed, K-sortable, Stripe-style IDs a person can read, copy and route back to their resource, with optional Ecto types and a prefix registry.
Examples are domain-free: a foundation package teaches no domain.
