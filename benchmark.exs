Benchee.run(
  %{
    "UXID.generate" => fn -> UXID.generate() end,
    "Ecto.ULID.generate" => fn -> Ecto.ULID.generate() end
  },
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/uxid_benchmark.html", auto_open: false}
  ]
)
