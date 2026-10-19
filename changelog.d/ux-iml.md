### Changed

- `UXID.decode/1` answers `{:error, reason}` on a malformed id, with the reason `:empty`, `:invalid_length` or `:invalid_character`, where it raised or answered `{:ok, codec}` with an unknown size or an unchecked body; deterministic bodies follow the same rule.
