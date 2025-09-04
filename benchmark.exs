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

Benchee.run(
  %{
    "UXID.decode" => fn uxid -> UXID.decode(uxid) end,
    "Decoder.process" => fn uxid -> UXID.Decoder.process(%UXID.Codec{string: uxid}) end
  },
  inputs: %{
    "UXID" => UXID.generate!(),
    "Prefixed UXID" => UXID.generate!(prefix: "bench")
  },
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/uxid_benchmark.html", auto_open: false}
  ]
)
