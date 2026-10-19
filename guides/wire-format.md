# UXID wire format

This page is the normative statement of what a UXID string is: how a producer
lays out the bits, which characters it emits, and what a decoder reads back. An
implementation in another language that follows this page produces and reads
the same strings as this library. It describes the format as uxid 2.10.0
ships it.

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be read as
described in [RFC 2119][rfc2119_url].

## Shape of an id

A UXID string is an optional prefix and a body:

    id     = [ prefix delimiter ] body
    body   = time-body / deterministic-body

- A **time body** is a time field followed by a random field. Its first
  character is never `z` or `Z`.
- A **deterministic body** is the marker character `z` (or `Z`) followed by hash
  characters. It carries no time.

Every body character is a character of the alphabet below. The body carries no
separators, no padding and no check symbol.

## Alphabet and case

The body uses Crockford Base32: 32 symbols, each standing for a 5-bit value.

| Value | Symbol | Value | Symbol | Value | Symbol | Value | Symbol |
|-------|--------|-------|--------|-------|--------|-------|--------|
| 0     | `0`    | 8     | `8`    | 16    | `G`    | 24    | `R`    |
| 1     | `1`    | 9     | `9`    | 17    | `H`    | 25    | `S`    |
| 2     | `2`    | 10    | `A`    | 18    | `J`    | 26    | `T`    |
| 3     | `3`    | 11    | `B`    | 19    | `K`    | 27    | `V`    |
| 4     | `4`    | 12    | `C`    | 20    | `M`    | 28    | `W`    |
| 5     | `5`    | 13    | `D`    | 21    | `N`    | 29    | `X`    |
| 6     | `6`    | 14    | `E`    | 22    | `P`    | 30    | `Y`    |
| 7     | `7`    | 15    | `F`    | 23    | `Q`    | 31    | `Z`    |

The letters `I`, `L`, `O` and `U` are not symbols.

- Case is display only. A producer MUST emit every body character in one case,
  lower or upper; this library emits lower case unless configured otherwise.
  An upper-case body and its lower-case spelling are the same id.
- A decoder MUST accept either case, and MUST read a symbol of either case as
  the same value.
- A decoder MUST NOT apply Crockford's reading substitutions (`I` or `L` as `1`,
  `O` as `0`) and MUST NOT skip hyphens: any character outside the table, in
  either case, is refused (see [Refusals](#refusals)).
- Case never applies to the prefix: a producer emits the prefix as given.

Because the symbols are in ASCII order within one case, comparing two bodies of
the same case character by character compares the values they encode.

## Bit packing

A field is written most significant bit first, cut into 5-bit groups, one
character per group.

**The partial-group rule.** When a field's width is not a multiple of 5, one
group is shorter than 5 bits. That group's character is the group's raw value,
not the value shifted left or padded with zero bits: a group of `k` bits holds a
value from 0 to 2^k - 1 and is written as that symbol.

- In the standard time field the short group is the **first** one (3 bits).
- In the random field the short group is the **last** one.

For example, the 16-bit random field `0xFFFF` is the groups `11111 11111 11111 1`
and encodes as `zzz1`. A padding encoding (RFC 4648 style) would write the last
group as `10000` (`g`); a UXID producer MUST NOT.

## Time field

The time is a count of milliseconds since the Unix epoch, an unsigned integer.

**Standard time** is 48 bits, written as 10 characters: one group of 3 bits,
then nine groups of 5 bits. A producer MUST supply a time from 0 to 2^48 - 1.
The first character is therefore always one of `0` to `7`.

**Compact time** is the low 40 bits of the millisecond time (the time modulo
2^40), written as 8 groups of 5 bits with no short group.

- A producer MUST refuse a compact time whose first character would have the
  value 31 (the low 40 bits at or above 31 x 2^35): that symbol is the
  deterministic marker. In wall-clock terms the refusal applies from mid-2038
  until the 40-bit window rolls over in 2039. This library raises
  `ArgumentError`; a standard time is never refused for this reason.
- The high bits of the time are not on the wire; see
  [Decoding the time](#decoding-the-time).

For the time 1700000000000 ms:

| Form     | Bits                                                   | Characters   |
|----------|--------------------------------------------------------|--------------|
| standard | `000 00001 10001 01111 00111 11110 01010 11010 00000 00000` | `01hf7yat00` |
| compact  | `10001 01111 00111 11110 01010 11010 00000 00000`       | `hf7yat00`   |

## Random field

The random field is a whole number of bytes, written as `ceil(8 x bytes / 5)`
characters under the partial-group rule. A producer MUST fill it from a
cryptographically secure random source, except under monotonic generation
(below), which derives later values in a millisecond from an earlier seed.

A random field MUST NOT be wider than 10 bytes at any size.

## Sizes

A size fixes the time form and the random width. Compact time hands the 8 bits
it frees from the time to the random field, so a compact id carries the same
number of bits as a standard one of its size, except at xl.

| Size | Mode     | Time bits | Random bytes | Random chars | Total bytes | Total bits | Body length |
|------|----------|-----------|--------------|--------------|-------------|------------|-------------|
| xs   | standard | 48        | 0            | 0            | 6           | 48         | 10          |
| s    | standard | 48        | 2            | 4            | 8           | 64         | 14          |
| m    | standard | 48        | 5            | 8            | 11          | 88         | 18          |
| l    | standard | 48        | 7            | 12           | 13          | 104        | 22          |
| xl   | standard | 48        | 10           | 16           | 16          | 128        | 26          |
| xs   | compact  | 40        | 1            | 2            | 6           | 48         | 10          |
| s    | compact  | 40        | 3            | 5            | 8           | 64         | 13          |
| m    | compact  | 40        | 6            | 10           | 11          | 88         | 18          |
| l    | compact  | 40        | 8            | 13           | 13          | 104        | 21          |
| xl   | compact  | 40        | 10           | 16           | 15          | 120        | 24          |

Compact xl is the one compact row that does not gain a random byte: the random
field is capped at 10 bytes, so compact xl is 8 bits shorter than standard xl.

The body lengths are the time characters plus the random characters. The
default size is xl, standard. A body generated with an explicit random width
outside this table has the same layout, but its length is not a table entry
and a decoder refuses it.

## Prefix and delimiter

- The **delimiter** is a non-empty string, `_` unless configured otherwise.
  Producer and decoder MUST agree on it; it is not recorded in the id.
- The **prefix** is any string. An empty prefix and an absent prefix are the
  same thing: no prefix. For no prefix a producer MUST emit the bare body, with
  no delimiter.
- A prefix MAY contain the delimiter (`a_b` is a valid prefix under `_`).
- A decoder MUST take the body as everything after the **last** occurrence of
  the delimiter, and the prefix as everything before it. A string with no
  delimiter is a body with no prefix.
- A string that starts with the delimiter is not one a producer emits; this
  library's decoder reports its prefix as the empty string, and a reader SHOULD
  treat that as no prefix.
- A delimiter made of alphabet characters makes the split above ambiguous and
  is not supported.

For example, under `_`: `cus_01hf7yat000001` is prefix `cus`, body
`01hf7yat000001`; `a_b_01hf7yat000001` is prefix `a_b`, the same body.

## Deterministic bodies

A deterministic body is a hash of a caller-supplied string, so the same inputs
always give the same id. Its layout:

1. **The hash input** is the byte string `prefix || 0x00 || from || 0x00 ||
   count`, where `prefix` is the prefix's bytes (empty for no prefix), `from`
   is the input string's bytes, `0x00` is one zero byte, and `count` is one
   byte holding the number of hash characters for the size.
2. **The digest** is SHA-256 of that input.
3. **The body** is the marker followed by the first `count x 5` bits of the
   digest, most significant bit first, as `count` characters of 5 bits (no
   short group).

| Size | Hash characters (`count`) | Hash bits | Body length |
|------|---------------------------|-----------|-------------|
| xs   | 9                         | 45        | 10          |
| s    | 13                        | 65        | 14          |
| m    | 17                        | 85        | 18          |
| l    | 21                        | 105       | 22          |
| xl   | 25                        | 125       | 26          |

- The marker is `z` in a lower-case id and `Z` in an upper-case one. Case is not
  part of the hash input.
- Deterministic bodies use the standard body lengths; there is no compact
  deterministic form.
- Because `count` is in the hash input, the same string at two sizes gives
  unrelated bodies, not one a truncation of the other. Because the prefix is,
  the same string under two prefixes gives unrelated bodies.
- A producer MUST refuse a request that asks for both a deterministic body and
  monotonic generation.

**Why the marker sorts last.** The marker is value 31, the highest symbol. A
standard time body starts with a value from 0 to 7, and a compact one with a
value from 0 to 30 (31 is refused above), so within one prefix and one case every
deterministic id sorts after every time-based id.

These three ids lock the format; an implementation MUST reproduce them:

| Prefix | `from`              | Size | Id                               |
|--------|---------------------|------|----------------------------------|
| `usr`  | `alice@example.com` | xl   | `usr_zcvt7epac0t1ebcsjfyf7cwz25` |
| `cus`  | `acme-corp`         | s    | `cus_zt9vnyfd85bff0`             |
| none   | `alice@example.com` | m    | `zqz4cwzgyw8ks97869`             |

For the first, the hash input is the bytes of `usr`, `0x00`, the bytes of
`alice@example.com`, `0x00`, and `0x19` (25).

## Monotonic generation

Monotonic generation keeps ids unique and in order within one millisecond from
one generator. It changes how the random field's value is chosen, never the
layout: a monotonic id is a time body of the same size and length, and nothing
in it says it was generated monotonically. A decoder reads it as any other time
body.

A producer that offers it MUST behave as follows. State is kept per generator
(in this library, per process), per prefix and per random width, as the last
time `T` and the last random value `R`, the random field read as one big-endian
unsigned integer of `w` bytes.

1. With no state, or a current time later than `T`, the random field is a fresh
   secure random value, and the id carries the current time.
2. With a current time equal to or earlier than `T`, the id carries `T` (not
   the current time) and the random value `R + step`, where `step` is drawn
   uniformly from 1 to 2^(4w) inclusive (half the field's bit width).
3. When `R + step` is 2^(8w) or more, the id carries `T + 1` and a fresh secure
   random value instead.

The step is not a plus-one counter: consecutive ids in a millisecond are spread
across a window of 2^(4w) values. That removes trivial enumeration, but it is a
mitigation, not unpredictability; see
[Why monotonic mode exists](monotonic.md). A monotonic xs uses compact time so
that it has a 1-byte field to step; this library refuses a monotonic xs with
an explicit standard time.

## Decoding

A decoder reads a string to: the prefix (or none), the size, whether the time is
compact, whether the body is deterministic, and the time (none for a
deterministic body). It does not report the random field: this library answers
the random field and its width as not supported on decode.

### Length to size

The body length alone gives the size and the time form. This is the length
table. The length is counted in bytes: every body character a producer emits
is one ASCII byte, and counting bytes gives every decoder the same length for
any other input too.

| Body length (bytes) | Size | Mode     |
|---------------------|------|----------|
| 10                  | xs   | standard |
| 13                  | s    | compact  |
| 14                  | s    | standard |
| 18                  | m    | standard |
| 21                  | l    | compact  |
| 22                  | l    | standard |
| 24                  | xl   | compact  |
| 26                  | xl   | standard |

**The 10 and 18 ambiguities.** A compact xs body and a compact m body have the
lengths of a standard xs and a standard m body (10 and 18). A decoder MUST read
both lengths as standard. The size it reports is then right, but a compact xs or
compact m id decodes with a wrong time: its 8 time characters and the first 2
random characters are read as a 10-character standard time. A producer that
needs the time back SHOULD NOT use compact xs or compact m. A monotonic xs is
compact, so its time does not decode either.

### The marker on decode

A body whose first character is `z` or `Z` is deterministic. The decoder reports
its size from the length (always a standard length) and no time.

### Decoding the time

- **Standard time:** the first 10 characters are the 48-bit time, read with the
  3-bit first group. The decoder takes the first character's low 3 bits; a
  producer never emits a first character above 7.
- **Compact time:** the first 8 characters are the low 40 bits of the time. The
  decoder supplies the high bits from its own clock: it combines the clock's
  bits above bit 40 with the 40 decoded bits, and when that result is more than
  86400000 ms (one day) ahead of its clock, it subtracts 2^40. The time is exact
  while the id and the decoder's clock fall in the same 2^40 ms window (about
  34.8 years) and the id is no more than one day ahead of the clock. An id from
  the previous window is recovered by the subtraction when it is less than
  2^40 ms minus one day older than the clock.

### Refusals

A body is well formed when every character is in the alphabet (either case)
and its length in bytes is in the length table above. A decoder MUST decode a
well-formed body and MUST refuse any other input with one of these reasons.
The rule is the same for deterministic bodies: a body starting with the marker
is decoded only when it is well formed.

| Reason              | When                                                         |
|---------------------|--------------------------------------------------------------|
| `empty`             | the body is empty (an empty string, or one ending in the delimiter) |
| `invalid_character` | a body character is not in the alphabet in either case       |
| `invalid_length`    | the body length in bytes is not in the length table          |

A body that fails more than one rule is refused for the first it fails, checked
in this order: `empty`, `invalid_length`, `invalid_character`.

The reasons are a closed set of names, not messages. In this library
`UXID.decode/1` answers `{:ok, codec}` or `{:error, reason}` with the reason as
an atom.

## Out of scope

These are part of this library but not of the wire format, and a conforming
implementation need not provide them:

- **The registry** (`UXID.Registry`): the compile-time map from prefix to
  resource and its JSON manifest. See [Registry reference](registry-reference.md).
- **The Ecto types**: storage and casting in an Ecto schema. See
  [How to use UXIDs in Ecto schemas](ecto.md).
- **A UUIDv7 body mode**: a body carrying a UUIDv7 is not part of this format.

The sizes' collision math is in [Sizes & Encoding](sizes.md); the deterministic
`from:` option is in [Deterministic IDs reference](deterministic-reference.md).

<!-- LINKS -->
[rfc2119_url]: https://www.rfc-editor.org/rfc/rfc2119
