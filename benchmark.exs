Benchee.run(
  %{
    "UXID.generate (10)" => fn -> UXID.generate(size: 10) end,
    "UXID.generate (0)" => fn -> UXID.generate(size: 0) end,
    "Ecto.ULID.generate" => fn -> Ecto.ULID.generate() end
  },
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/uxid_benchmark.html", auto_open: false}
  ]
)
