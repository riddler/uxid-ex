defmodule UXID.TestSupport.Org do
  @moduledoc false
end

defmodule UXID.TestSupport.Contact do
  @moduledoc false
end

defmodule UXID.TestSupport.IDs do
  @moduledoc false
  use UXID.Registry,
    default_size: :medium,
    default_validate: true

  defid :org, prefix: "org", schema: UXID.TestSupport.Org, category: :account

  defid :contact,
    prefix: "contact",
    size: :large,
    schema: UXID.TestSupport.Contact,
    allow_uuid: false

  defid :lead, prefix: "lead"
  defid :in_ref, prefix: "in_ref", size: :small

  retired "usr"
end

# A schema that self-registers under a routed registry key via the marker
# mixin — the reference points down (schema names a key), never up.
defmodule UXID.TestSupport.Widget do
  @moduledoc false
  use UXID.Registered, key: :widget
end

# A layered-app style registry: `:widget` carries no compile-time `schema:`
# literal and is filled at boot by self-registration; `:gadget` is opted into
# routing but intentionally left unmapped for the completeness test.
defmodule UXID.TestSupport.RoutedIDs do
  @moduledoc false
  use UXID.Registry, default_size: :medium

  defid :widget, prefix: "wid", route: true
  defid :gadget, prefix: "gad", route: false
end
