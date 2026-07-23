defmodule UXID.Registry do
  @moduledoc """
  A compile-time registry of an application's UXID prefixes.

  Prefixes only deliver their value — "the ID names its resource on sight" — if
  they are globally unique and well-formed across an app. `use UXID.Registry`
  moves that governance out of hand-rolled CI tests and into the compiler, and
  turns the same declarations into a runtime routing table (prefix → schema)
  that powers authorization checks, admin auto-linking, and Relay-style global
  object identification.

  ## Declaring a registry

      defmodule MyApp.IDs do
        use UXID.Registry,
          prefix_format: ~r/^[a-z][a-z0-9_]{1,7}$/,
          delimiter: "_",
          default_size: :medium,
          default_validate: true

        defid :org,     prefix: "org",    schema: MyApp.Org,         category: :account
        defid :contact, prefix: "contact", size: :large, schema: MyApp.CRM.Contact, allow_uuid: true
        defid :lead,    prefix: "lead",   schema: MyApp.CRM.Lead
        retired "usr" # reserve a prefix so it counts for uniqueness, never reused
      end

  ## Compile-time guarantees

    * every `:prefix` is checked against `:prefix_format` — a malformed prefix is
      a compile error;
    * all prefixes (active *and* `retired`) are checked for uniqueness — a
      duplicate is a compile error. This replaces the per-app runtime uniqueness
      test.

  ## Generated API

  By key (minting and schema configuration):

      MyApp.IDs.generate!(:org)   # => "org_01h…"
      MyApp.IDs.prefix(:org)      # => "org"
      MyApp.IDs.size(:org)        # => :medium
      MyApp.IDs.schema(:org)      # => MyApp.Org
      MyApp.IDs.field_opts(:org)  # => [prefix: "org", size: :medium, validate: true, allow_uuid: true, delimiter: "_"]
      MyApp.IDs.all()             # => [%{key: :org, prefix: "org", ...}, ...]

  Cross-source single source of truth — emit a JSON manifest so a database
  function or a mobile/JS generator mints prefixes the same way the app does:

      MyApp.IDs.manifest()        # => [%{"key" => "org", "prefix" => "org", "size" => "medium", ...}]
      MyApp.IDs.manifest_json()   # => ~s([{"key":"org","prefix":"org","size":"medium","category":"account"},...])

  `field_opts/1` is the single-source-of-truth hook — a schema spreads it instead
  of restating anything:

      @primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:org)}

  By ID string (runtime routing — see "Parsing" below):

      MyApp.IDs.known?("org_01h…")      # => true   (cheap prefix-only membership)
      MyApp.IDs.key_for("org_01h…")     # => :org
      MyApp.IDs.schema_for("org_01h…")  # => MyApp.Org
      MyApp.IDs.resolve("org_01h…")     # => %{key: :org, schema: MyApp.Org, ...}

  ## Parsing

  Lookups split an ID into `{prefix, body}` on the **last** delimiter. This is
  unambiguous without consulting the registry, because a UXID body is Crockford
  Base32 and therefore never contains the delimiter: in `in_ref_01h…` every `_`
  belongs to the prefix except the final joining one. The registry is consulted
  only *after* the split, to answer membership/type — an unregistered but
  well-formed string like `nope_01h…` parses fine yet resolves to `nil`.

  Because of that, the `:delimiter` must be a character that cannot appear in a
  Base32 body (`"_"` or `"-"`); a letter or digit is rejected at compile time.
  An underscore is preferred for compound prefixes since it does not break
  double-click-to-select-the-whole-id.

  ## Routing in a layered app (self-registration)

  A `schema:` literal points the registry *up* at a schema module. In a flat app
  that is fine, and `schema_for/1` resolves it with no further setup. In a
  **layered** app the registry usually lives at the base layer (so every layer
  can depend down on it to mint IDs and read `field_opts/1`), while the schemas
  it routes to live above it — so naming them inverts the dependency direction.

  To keep the direction correct, omit `schema:` and let each schema register
  itself under its key with `UXID.Registered`. The reference then points *down*
  (schema → registry key):

      defmodule MyApp.CRM.Contact do
        use Ecto.Schema
        use UXID.Registered, key: :contact
        @primary_key {:id, UXID, [autogenerate: true] ++ MyApp.IDs.field_opts(:contact)}
      end

      defmodule MyApp.IDs do
        use UXID.Registry
        defid :contact, prefix: "contact", route: true  # filled at boot, no schema literal
      end

  At boot, `verify!/1` scans the given OTP apps for the marker, assembles the
  prefix → schema routing table into `:persistent_term`, and validates it —
  raising if a marker names an unregistered key, two modules claim one key, or a
  `route: true` key resolves to no schema. Wire it into your top app's `start/2`
  so every boot (prod, dev, and CI's `mix test`) re-verifies:

      def start(_type, _args) do
        MyApp.IDs.verify!(otp_apps: [:my_app])
        # ...
      end

  Because the registry discovers schemas by runtime reflection rather than a
  compile-visible module reference, no base-layer code ever names an upper-layer
  module, so `Boundary`/`xref` see nothing pointing the wrong way. `known?/1` and
  `key_for/1` need no schema at all and work regardless.
  """

  @default_prefix_format ~r/^[a-z][a-z0-9_]{1,7}$/

  # A Base32 body character in either case; a delimiter must NOT be one of these,
  # otherwise the split-on-last-delimiter rule becomes ambiguous.
  @body_char ~r/\A[0-9ABCDEFGHJKMNPQRSTVWXYZabcdefghjkmnpqrstvwxyz]\z/

  @doc "The built-in default `:prefix_format` (permits an internal underscore)."
  def default_prefix_format(), do: @default_prefix_format

  @doc """
  Splits a UXID string into `{prefix, body}` on the last occurrence of
  `delimiter`. Returns `{nil, string}` when the delimiter is absent.

      iex> UXID.Registry.split_last("in_ref_01h2x…", "_")
      {"in_ref", "01h2x…"}

      iex> UXID.Registry.split_last("01h2x…", "_")
      {nil, "01h2x…"}
  """
  @spec split_last(String.t(), String.t()) :: {String.t() | nil, String.t()}
  def split_last(string, delimiter) when is_binary(string) and is_binary(delimiter) do
    case :binary.matches(string, delimiter) do
      [] ->
        {nil, string}

      matches ->
        {pos, len} = List.last(matches)
        <<prefix::binary-size(pos), _::binary-size(len), body::binary>> = string
        {prefix, body}
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import UXID.Registry, only: [defid: 1, defid: 2, retired: 1]

      Module.register_attribute(__MODULE__, :uxid_entries, accumulate: true)
      Module.register_attribute(__MODULE__, :uxid_reserved, accumulate: true)

      @uxid_prefix_format Keyword.get(opts, :prefix_format, UXID.Registry.default_prefix_format())
      @uxid_delimiter Keyword.get(opts, :delimiter, UXID.default_delimiter())
      @uxid_default_size Keyword.get(opts, :default_size)
      @uxid_default_validate Keyword.get(opts, :default_validate, true)

      @before_compile UXID.Registry
    end
  end

  @doc """
  Registers an id under `key`. Requires `:prefix`; `:size`, `:schema`,
  `:category`, `:validate`, and `:allow_uuid` are optional and fall back to the
  registry defaults.
  """
  defmacro defid(key, opts \\ []) do
    quote bind_quoted: [key: key, opts: opts] do
      @uxid_entries {key, opts}
    end
  end

  @doc """
  Reserves a prefix so it participates in the uniqueness check but is never
  generated — mirroring "identifiers are never reused". Accepts a string or atom.
  """
  defmacro retired(prefix) do
    quote bind_quoted: [prefix: prefix] do
      @uxid_reserved prefix
    end
  end

  # This macro emits the registry's whole public API as one quoted block, so its
  # cyclomatic count reflects the number of generated functions, not branching
  # logic — the actual branching lives in the small runtime helpers below.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(env) do
    module = env.module
    format = Module.get_attribute(module, :uxid_prefix_format)
    delimiter = Module.get_attribute(module, :uxid_delimiter)
    default_size = Module.get_attribute(module, :uxid_default_size)
    default_validate = Module.get_attribute(module, :uxid_default_validate)

    validate_delimiter!(module, delimiter)

    entries =
      module
      |> Module.get_attribute(:uxid_entries)
      |> Enum.reverse()
      |> Enum.map(&normalize_entry(&1, module, default_size, default_validate))

    reserved =
      module
      |> Module.get_attribute(:uxid_reserved)
      |> Enum.reverse()
      |> Enum.map(&to_string/1)

    validate_keys!(module, entries)
    validate_formats!(module, entries, format)
    validate_uniqueness!(module, entries, reserved)

    index = Map.new(entries, &{&1.prefix, &1})
    by_key = Map.new(entries, &{&1.key, &1})

    # The generated module stays a thin façade of delegations; the branching
    # logic lives in the runtime helpers below so it is analysed (and tested)
    # once, rather than re-inlined into every registry.
    quote do
      @uxid_entries_data unquote(Macro.escape(entries))
      @uxid_by_key unquote(Macro.escape(by_key))
      @uxid_index unquote(Macro.escape(index))
      @uxid_reserved_data unquote(reserved)
      @uxid_delimiter_str unquote(delimiter)

      @doc "All registered (non-retired) ids, in declaration order."
      def all(), do: @uxid_entries_data

      @doc "The registered keys, in declaration order."
      def keys(), do: unquote(Enum.map(entries, & &1.key))

      @doc "Reserved (retired) prefixes — unique-checked but never generated."
      def reserved(), do: @uxid_reserved_data

      @doc """
      A JSON-safe manifest of the registered ids — a list of maps with string
      keys and scalar (`prefix`, `size`, `category`, `key`) values, `nil` where
      unset. This is the cross-source single source of truth: emit it so a
      database function or a mobile/JS generator mints prefixes the same way the
      Elixir app does. Encode it with any JSON library, or use `manifest_json/0`.
      """
      def manifest(), do: UXID.Registry.manifest(all())

      @doc "The `manifest/0` encoded as a JSON string (deterministic field order)."
      def manifest_json(), do: UXID.Registry.manifest_json(all())

      @doc "The registry entry for `key` (or `nil`)."
      def entry(key), do: Map.get(@uxid_by_key, key)

      @doc "The registry entry for `key`, raising if it is unknown."
      def fetch!(key), do: UXID.Registry.fetch_entry!(@uxid_by_key, key, __MODULE__)

      @doc "The prefix for `key`."
      def prefix(key), do: fetch!(key).prefix

      @doc "The size for `key`."
      def size(key), do: fetch!(key).size

      @doc "The schema module for `key` (or `nil`)."
      def schema(key), do: fetch!(key).schema

      @doc "The category for `key` (or `nil`)."
      def category(key), do: fetch!(key).category

      @doc """
      The Ecto field / `UXID` options for `key`: prefix, size, validate,
      allow_uuid, and the registry delimiter. Spread into a schema field.
      """
      def field_opts(key), do: UXID.Registry.field_opts_for(fetch!(key), @uxid_delimiter_str)

      @doc "Generates a UXID for `key`. See `UXID.generate!/1`."
      def generate!(key),
        do: UXID.generate!(UXID.Registry.gen_opts(fetch!(key), @uxid_delimiter_str))

      @doc "Generates a UXID for `key`, wrapped in `{:ok, uxid}`."
      def generate(key),
        do: UXID.generate(UXID.Registry.gen_opts(fetch!(key), @uxid_delimiter_str))

      @doc """
      The full registry entry for an ID string, or `nil` if its prefix is not
      registered. Parsing splits on the last delimiter; the registry answers
      membership/type.
      """
      def resolve(id), do: UXID.Registry.resolve_id(@uxid_index, id, @uxid_delimiter_str)

      @doc """
      Cheap prefix-only membership check for an ID string — the pre-filter for an
      IDOR scan path. Does not validate the body.
      """
      def known?(id), do: UXID.Registry.known_id?(@uxid_index, id, @uxid_delimiter_str)

      @doc "The registered key for an ID string (or `nil`)."
      def key_for(id), do: UXID.Registry.field_of(resolve(id), :key)

      @doc """
      The schema module for an ID string (or `nil`) — the prefix→schema map.
      Resolves a compile-time `schema:` literal first, then the runtime routing
      table built from schema self-registration (see `verify!/1`).
      """
      def schema_for(id),
        do:
          UXID.Registry.schema_for_id(
            @uxid_index,
            UXID.Registry.get_routes(__MODULE__),
            id,
            @uxid_delimiter_str
          )

      @doc "The registered prefixes, in declaration order."
      def prefixes(), do: unquote(Enum.map(entries, & &1.prefix))

      @doc """
      The current `%{key => schema_module}` routing table assembled from schema
      self-registration (see `UXID.Registered`). Empty until `build_routes!/1`
      or `verify!/1` runs.
      """
      def routes(), do: UXID.Registry.get_routes(__MODULE__)

      @doc """
      Builds the runtime routing table by scanning the modules of `:otp_apps`
      for the `UXID.Registered` marker and storing the prefix → schema map in
      `:persistent_term`. Idempotent. Pass the app names at the call site:

          #{inspect(__MODULE__)}.build_routes!(otp_apps: [:my_app])
      """
      def build_routes!(opts),
        do: UXID.Registry.build_routes(__MODULE__, @uxid_by_key, opts)

      @doc """
      Builds the routing table (`build_routes!/1`) and validates the registry:
      every marker key is registered, no key is claimed by two modules, and
      every `route: true` key resolves to a schema (compile-time literal or
      self-registration). Raises `ArgumentError` listing every problem, returns
      `:ok` otherwise.

      Call from your top app's `start/2` so every boot — prod, dev, and CI's
      `mix test` — verifies:

          def start(_type, _args) do
            MyApp.IDs.verify!(otp_apps: [:my_app])
            # ...
          end
      """
      def verify!(opts \\ []),
        do: UXID.Registry.verify(__MODULE__, @uxid_by_key, opts)
    end
  end

  # === Runtime helpers (called by generated registry modules) ===

  @doc false
  def fetch_entry!(by_key, key, module) do
    case Map.get(by_key, key) do
      nil ->
        raise ArgumentError,
              "#{inspect(key)} is not a registered UXID key in #{inspect(module)}. " <>
                "Known keys: #{inspect(Map.keys(by_key))}"

      entry ->
        entry
    end
  end

  @doc false
  def field_opts_for(entry, delimiter) do
    [
      prefix: entry.prefix,
      size: entry.size,
      validate: entry.validate,
      allow_uuid: entry.allow_uuid,
      delimiter: delimiter
    ]
  end

  @doc false
  def gen_opts(entry, delimiter),
    do: [prefix: entry.prefix, size: entry.size, delimiter: delimiter]

  @doc false
  def resolve_id(index, id, delimiter) when is_binary(id) do
    {prefix, _body} = split_last(id, delimiter)
    Map.get(index, prefix)
  end

  def resolve_id(_index, _id, _delimiter), do: nil

  @doc false
  def known_id?(index, id, delimiter) when is_binary(id) do
    {prefix, _body} = split_last(id, delimiter)
    Map.has_key?(index, prefix)
  end

  def known_id?(_index, _id, _delimiter), do: false

  @doc false
  def field_of(nil, _field), do: nil
  def field_of(entry, field), do: Map.get(entry, field)

  # === Runtime routing helpers (self-registration; called at boot) ===

  @doc false
  def get_routes(module), do: :persistent_term.get({__MODULE__, module}, %{})

  @doc false
  def schema_for_id(index, routes, id, delimiter) do
    case resolve_id(index, id, delimiter) do
      nil -> nil
      entry -> entry.schema || Map.get(routes, entry.key)
    end
  end

  @doc false
  def build_routes(module, by_key, opts) do
    markers = collect_markers(fetch_apps!(opts))
    routes = validate_markers!(module, by_key, markers)
    :persistent_term.put({__MODULE__, module}, routes)
    routes
  end

  @doc false
  def verify(module, by_key, opts) do
    build_routes(module, by_key, opts)
    :ok
  end

  # Scans the given OTP apps for modules carrying the `UXID.Registered` marker,
  # force-loading each so `function_exported?/3` sees it — that force-load is
  # what makes the table complete at boot even for otherwise-lazy modules.
  @doc false
  def collect_markers(apps) do
    for app <- apps, mod <- app_modules(app), marked?(mod), do: {mod.__uxid_key__(), mod}
  end

  # Validates a collected marker list against the registry and returns the
  # `%{key => module}` routing map. Split out from the app scan so the
  # validation rules can be tested with crafted marker lists.
  @doc false
  def validate_markers!(module, by_key, markers) do
    validate_marker_keys!(module, by_key, markers)
    validate_marker_dups!(module, markers)
    routes = Map.new(markers)
    validate_route_completeness!(module, by_key, routes)
    routes
  end

  defp app_modules(app) do
    _ = Application.load(app)
    Application.spec(app, :modules) || []
  end

  defp marked?(mod), do: Code.ensure_loaded?(mod) and function_exported?(mod, :__uxid_key__, 0)

  defp fetch_apps!(opts) do
    case Keyword.get(opts, :otp_apps) do
      apps when is_list(apps) and apps != [] ->
        apps

      other ->
        raise ArgumentError,
              ":otp_apps must be a non-empty list of OTP application names, got: #{inspect(other)}"
    end
  end

  defp validate_marker_keys!(module, by_key, markers) do
    unknown = for {key, mod} <- markers, not Map.has_key?(by_key, key), do: {key, mod}

    unless unknown == [] do
      detail =
        Enum.map_join(unknown, ", ", fn {key, mod} -> "#{inspect(key)} (#{inspect(mod)})" end)

      raise ArgumentError,
            "UXID markers reference keys not registered in #{inspect(module)}: " <> detail
    end
  end

  defp validate_marker_dups!(module, markers) do
    dups =
      markers
      |> Enum.group_by(fn {key, _mod} -> key end, fn {_key, mod} -> mod end)
      |> Enum.filter(fn {_key, mods} -> length(Enum.uniq(mods)) > 1 end)

    unless dups == [] do
      detail =
        Enum.map_join(dups, "; ", fn {key, mods} ->
          "#{inspect(key)} claimed by #{inspect(Enum.uniq(mods))}"
        end)

      raise ArgumentError,
            "UXID keys claimed by multiple modules in #{inspect(module)}: " <> detail
    end
  end

  defp validate_route_completeness!(module, by_key, routes) do
    missing =
      for {key, entry} <- by_key,
          entry.route,
          is_nil(entry.schema),
          not Map.has_key?(routes, key),
          do: key

    unless missing == [] do
      raise ArgumentError,
            "UXID keys marked route: true but not mapped to a schema in #{inspect(module)}: " <>
              inspect(missing)
    end
  end

  @manifest_fields [:key, :prefix, :size, :category]

  @doc false
  def manifest(entries) do
    Enum.map(entries, fn entry ->
      Map.new(@manifest_fields, fn field ->
        {Atom.to_string(field), scalar(Map.get(entry, field))}
      end)
    end)
  end

  @doc false
  def manifest_json(entries) do
    "[" <> Enum.map_join(entries, ",", &entry_json/1) <> "]"
  end

  # A registry field value rendered as a JSON-safe scalar: atoms become strings,
  # nil stays nil (JSON null), strings pass through.
  defp scalar(nil), do: nil
  defp scalar(value) when is_atom(value), do: Atom.to_string(value)
  defp scalar(value) when is_binary(value), do: value

  defp entry_json(entry) do
    inner =
      Enum.map_join(@manifest_fields, ",", fn field ->
        json_string(Atom.to_string(field)) <> ":" <> json_value(scalar(Map.get(entry, field)))
      end)

    "{" <> inner <> "}"
  end

  defp json_value(nil), do: "null"
  defp json_value(value) when is_binary(value), do: json_string(value)

  defp json_string(value), do: IO.iodata_to_binary([?", escape(value), ?"])

  defp escape(string), do: for(<<char <- string>>, into: "", do: escape_char(char))

  defp escape_char(?\"), do: "\\\""
  defp escape_char(?\\), do: "\\\\"
  defp escape_char(?\n), do: "\\n"
  defp escape_char(?\r), do: "\\r"
  defp escape_char(?\t), do: "\\t"

  defp escape_char(char) when char < 0x20,
    do: "\\u" <> String.pad_leading(Integer.to_string(char, 16), 4, "0")

  defp escape_char(char), do: <<char>>

  # === Compile-time helpers (run inside __before_compile__) ===

  defp normalize_entry({key, opts}, module, default_size, default_validate) do
    unless is_atom(key) do
      raise ArgumentError, "defid key must be an atom in #{inspect(module)}, got: #{inspect(key)}"
    end

    prefix = Keyword.get(opts, :prefix)

    unless is_binary(prefix) do
      raise ArgumentError,
            "defid #{inspect(key)} in #{inspect(module)} requires a string :prefix, " <>
              "got: #{inspect(prefix)}"
    end

    schema = Keyword.get(opts, :schema)

    %{
      key: key,
      prefix: prefix,
      size: Keyword.get(opts, :size, default_size),
      schema: schema,
      category: Keyword.get(opts, :category),
      validate: Keyword.get(opts, :validate, default_validate),
      allow_uuid: Keyword.get(opts, :allow_uuid, true),
      # A key "must route" (verify!/1 fails if it resolves to no schema) when it
      # carries a compile-time `schema:` literal, or is explicitly opted in with
      # `route: true` so a self-registered schema is required to fill it.
      route: Keyword.get(opts, :route, not is_nil(schema))
    }
  end

  defp validate_delimiter!(module, delimiter) do
    valid? =
      is_binary(delimiter) and String.length(delimiter) == 1 and
        not Regex.match?(@body_char, delimiter)

    unless valid? do
      raise ArgumentError,
            "UXID.Registry :delimiter in #{inspect(module)} must be a single character that " <>
              "cannot appear in a Base32 body (e.g. \"_\" or \"-\"), got: #{inspect(delimiter)}"
    end
  end

  defp validate_keys!(module, entries) do
    entries
    |> Enum.map(& &1.key)
    |> duplicates()
    |> case do
      [] -> :ok
      dupes -> raise ArgumentError, "duplicate UXID keys in #{inspect(module)}: #{inspect(dupes)}"
    end
  end

  defp validate_formats!(module, entries, format) do
    for %{key: key, prefix: prefix} <- entries, not Regex.match?(format, prefix) do
      raise ArgumentError,
            "UXID prefix #{inspect(prefix)} for #{inspect(key)} in #{inspect(module)} does not " <>
              "match #{inspect(format)}"
    end

    :ok
  end

  defp validate_uniqueness!(module, entries, reserved) do
    (Enum.map(entries, & &1.prefix) ++ reserved)
    |> duplicates()
    |> case do
      [] ->
        :ok

      dupes ->
        raise ArgumentError,
              "duplicate UXID prefixes in #{inspect(module)} (including retired): " <>
                inspect(dupes)
    end
  end

  defp duplicates(list) do
    list
    |> Enum.frequencies()
    |> Enum.filter(fn {_value, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
  end
end
