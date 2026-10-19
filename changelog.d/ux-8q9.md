### Fixed

- Compact xlarge ids (`size: :xl, compact_time: true`) now generate, carrying 10 random bytes (they asked for 11, which the encoder could not produce, and raised), and an explicit `rand_size` above 10 raises an `ArgumentError` naming the 10-byte cap.
