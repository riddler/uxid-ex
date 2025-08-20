# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

This is an Elixir project using Mix as the build tool. Common commands:

- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project (with warnings as errors enabled)
- `mix test` - Run all tests
- `mix test test/path/to/specific_test.exs` - Run a specific test file
- `mix docs` - Generate documentation
- `mix coverage` - Generate test coverage report (HTML format)

## Project Structure

UXID-EX is an Elixir library for generating User eXperience focused IDentifiers (UXIDs) - secure, k-sortable, prefixed identifiers similar to Stripe IDs.

### Core Architecture

The library follows a pipeline-based architecture:

**Main Module (`lib/uxid.ex`)**
- Primary public API with `generate/1`, `generate!/1`, `new/1`, and `decode/1` functions
- Conditionally includes Ecto.ParameterizedType behavior when Ecto is available
- Acts as orchestrator between Encoder and Decoder modules

**Encoder Pipeline (`lib/uxid/encoder.ex`)**
- Transforms UXID structs through: time → rand_size → randomness → encoding → prefixing
- Supports configurable sizes (xs/xsmall through xl/xlarge) that determine randomness bytes
- Uses Crockford Base32 encoding (excludes I, L, O, U for readability)

**Decoder Pipeline (`lib/uxid/decoder.ex`)**
- Reverses encoding process: prefix separation → time extraction → size inference
- Time decoding is fully supported; rand/size decoding returns `:decode_not_supported`

**Ecto Integration (`lib/uxid/ecto_type.ex`)**
- Provides seamless database integration as a custom Ecto type
- Supports autogeneration with configurable prefix and size options
- Primary key and field usage through `@primary_key` and schema field definitions

### Key Design Patterns

- **Struct-based pipeline**: Each module receives and returns UXID structs, building state progressively
- **Size abstraction**: T-shirt sizes (xs, s, m, l, xl) map to specific randomness byte counts (0, 2, 5, 7, 10)
- **Conditional compilation**: Ecto integration only loaded when Ecto is available
- **Error handling**: Consistent `{:ok, result} | {:error, reason}` pattern with bang variants

## Testing

Tests are organized by module:
- `test/uxid_test.exs` - Main API tests
- `test/uxid/encoder_test.exs` - Encoder-specific tests  
- `test/uxid/decoder_test.exs` - Decoder-specific tests
- `test/uxid/ecto_type_test.exs` - Ecto integration tests

The project enforces warnings as errors and includes comprehensive test coverage reporting.