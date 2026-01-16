### Upcoming

* Adds min_size config option to enforce minimum UXID sizes (useful for test environments)
* Adds compact_time feature for improved collision resistance in small UXIDs:
  - Global policy via `compact_small_times` config automatically compacts :xs/:xsmall/:s/:small sizes
  - Per-call override via `compact_time: true/false` option works for any size
  - Uses 40-bit timestamps (8 chars) instead of 48-bit (10 chars), freeing 8 bits for randomness
  - Example: :small gains 50% more randomness (24 bits vs 16 bits)
  - Decoder automatically detects compact format from length and reconstructs full timestamp
  - K-sortability maintained until ~September 2039

### 2.2.0 / 2025-09-12

* Adds UXID.Decoder module with full pipeline processing and uppercase/lowercase support

### 2.1.0 / 2025-09-10

* Adds delimiter option (default is '_')
* Adds UXID.Codec with encoding struct and type
* Fixes Dialyzer issues
* Changes UXID type to String.t() to work better with TypedEctoSchema
* Changes how Ecto.Paramaterized type is implemented to work in projects without Ecto

### 2.0.0 / 2025-04-27

#### Breaking Changes

* Adds case config and functionality
* Makes lowercase the default
* Removes deprecated Ecto.UXID

### 1.0.0 / 2025-04-13

* Fixes compiler warnings

### 0.2.3 / 2020-11-29

* Uses new project URL

### 0.2.2 / 2020-11-26

* Passes options cleanly down for autogenerate

### 0.2.1 / 2020-11-24

* Updates Mix project description

## 0.2.0 / 2020-11-22

* Deprecates Ecto.UXID
* Removes Decoder and CrockfordBase32
* Adds size option (T-Shirt sizes)

### 0.1.2 / 2020-11-07

* Updates description and README

### 0.1.1 / 2020-11-07

* Updates description and README

## 0.1.0 / 2020-11-06

* Updates description and README
* Has enough usable functionality and documentation for 0.1.0!

### 0.0.6 / 2020-10-30

* Marks Ecto as optional dependency and excludes xref

### 0.0.5 / 2020-10-19

* Adds Ecto.UXID

### 0.0.4 / 2020-10-19

* Includes Erlang crypto application

### 0.0.3 / 2020-10-12

* Fixes documentation

### 0.0.2 / 2020-10-11

* Adds generation of UXIDs

### 0.0.1 / 2020-06-17

* Birthday!
