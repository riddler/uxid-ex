### Added

- A `rand:` option on `UXID.generate/1`, `UXID.generate!/1` and `UXID.new/1` fixes the random field to the given bytes, so a fixed time and a fixed `rand:` build a reproducible id for test vectors; it raises `ArgumentError` when its width does not match the random field, with `from:`, and under monotonic generation, and is never a source of randomness in production.
