# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  # Registry DSL — keep these paren-free, and export the rule so apps that
  # `use UXID.Registry` format their declarations the same way.
  locals_without_parens: [defid: 1, defid: 2, retired: 1],
  export: [locals_without_parens: [defid: 1, defid: 2, retired: 1]]
]
